import importlib.util
from pathlib import Path
import tempfile
import tomllib
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("installer", Path(__file__).resolve().parents[1] / "install.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
NL = chr(10)
BASE = NL.join(['[bar.default]', 'start = ["workspaces", "clock"]', 'thickness = 33', '[shell]', 'theme = "custom"', ''])
EFFECTIVE = tomllib.loads(BASE)


class InstallerTests(unittest.TestCase):
    def test_additive_and_idempotent(self):
        text = mod.transform(BASE, EFFECTIVE)
        data = tomllib.loads(text)
        self.assertEqual(data["bar"]["default"]["start"], ["workspaces", "clock", "project-tasks", "sleep-guard"])
        self.assertEqual(data["bar"]["default"]["thickness"], 33)
        self.assertEqual(data["shell"], EFFECTIVE["shell"])
        self.assertEqual(mod.transform(text, data), text)

    def test_partial_install_preserves_task_widget(self):
        text = mod.transform(BASE, EFFECTIVE)
        text = text.replace(', "sleep-guard"]', ']')
        updated = mod.transform(text, tomllib.loads(text))
        data = tomllib.loads(updated)
        self.assertEqual(data["bar"]["default"]["start"].count("project-tasks"), 1)
        self.assertEqual(data["bar"]["default"]["start"].count("sleep-guard"), 1)

    def test_inherits_existing_effective_defaults(self):
        text = mod.transform('[shell]' + NL + 'foo = "bar"' + NL, EFFECTIVE)
        self.assertEqual(tomllib.loads(text)["bar"]["default"]["start"][:2], ["workspaces", "clock"])

    def test_rejects_conflicting_widget(self):
        text = BASE + '[widget.sleep-guard]' + NL + 'type = "other"' + NL
        with self.assertRaisesRegex(ValueError, "conflict"):
            mod.transform(text, tomllib.loads(text))

    def test_rejects_custom_bar_selection(self):
        with self.assertRaisesRegex(ValueError, "Custom bar"):
            mod.transform(BASE, {"bar": {"order": ["custom"]}})

    def test_multiline_fails_without_modification(self):
        text = BASE.replace('["workspaces", "clock"]', '[' + NL + '"workspaces",' + NL + '"clock"]')
        with self.assertRaisesRegex(ValueError, "Multiline"):
            mod.transform(text, tomllib.loads(text))

    def test_commented_single_line_array(self):
        text = BASE.replace('start = ["workspaces", "clock"]', 'start = ["workspaces", "clock"] # note')
        self.assertEqual(tomllib.loads(mod.transform(text, tomllib.loads(text)))["shell"], EFFECTIVE["shell"])

    def test_conflicting_source(self):
        with self.assertRaisesRegex(ValueError, "different"):
            mod.source_present("dotfiles git https://example.com/other")
        self.assertTrue(mod.source_present("dotfiles path " + str(mod.SOURCE)))

    def test_enabled_list_ignores_disabled(self):
        self.assertEqual(mod.enabled_ids("pn/project-tasks [dotfiles] 1.0.0 enabled\npn/sleep-guard [dotfiles] 1.0.0 disabled"), {"pn/project-tasks"})

    def test_atomic_backup_and_preservation(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "settings.toml"
            p.write_text(BASE)
            candidate = mod.transform(BASE, EFFECTIVE)
            with patch.object(mod, "run", return_value="valid"):
                backup = mod.atomic_settings(p, BASE, candidate)
            self.assertEqual(backup.read_text(), BASE)
            self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
            self.assertEqual(p.read_text(), candidate)

    def test_invalid_candidate_leaves_original(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "settings.toml"; p.write_text(BASE)
            with patch.object(mod, "run", side_effect=RuntimeError("bad TOML")):
                with self.assertRaises(RuntimeError):
                    mod.atomic_settings(p, BASE, "bad")
            self.assertEqual(p.read_text(), BASE)

    def test_concurrent_change_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "settings.toml"; p.write_text(BASE)
            def changed(*args): p.write_text(BASE + '# changed' + NL); return 'valid'
            with patch.object(mod, "run", side_effect=changed):
                with self.assertRaisesRegex(ValueError, "changed"):
                    mod.atomic_settings(p, BASE, mod.transform(BASE, EFFECTIVE))
            self.assertTrue(p.read_text().endswith('# changed' + NL))

    def test_symlink_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"; source.write_text(BASE)
            p = Path(directory) / "settings.toml"; p.symlink_to(source)
            with self.assertRaisesRegex(ValueError, "symlink"):
                mod.atomic_settings(p, BASE, mod.transform(BASE, EFFECTIVE))
            self.assertEqual(source.read_text(), BASE)


if __name__ == "__main__":
    unittest.main()
