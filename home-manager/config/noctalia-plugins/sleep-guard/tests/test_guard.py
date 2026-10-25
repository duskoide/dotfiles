"""No sleep calls: unit tests mock all process/systemd operations."""
import importlib.util
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("guard", Path(__file__).resolve().parents[1] / "guard.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


def row(**kw):
    data = dict(who=guard.WHO, uid=os.getuid(), pid=123, mode="block", what="sleep:handle-lid-switch")
    data.update(kw)
    return data


def info(**kw):
    data = dict(LoadState="loaded", ActiveState="active", MainPID="123", Transient="yes", Description=guard.DESCRIPTION)
    data.update(kw)
    return data


class GuardTests(unittest.TestCase):
    def test_exact_inhibitor_identity(self):
        self.assertTrue(guard.matches(row(), 123))
        for wrong in [dict(uid=-1), dict(pid=124), dict(mode="delay"), dict(mode="block-weak"),
                      dict(what="sleep"), dict(what="idle:sleep:handle-lid-switch"), dict(who="other")]:
            self.assertFalse(guard.matches(row(**wrong), 123))

    def test_active_needs_verified_lock(self):
        with patch.object(guard, "unit_info", return_value=info()), patch.object(guard, "inhibitors", return_value=[row()]):
            self.assertEqual(guard.status(), {"state": "on", "pid": 123})
        with patch.object(guard, "unit_info", return_value=info()), patch.object(guard, "inhibitors", return_value=[]):
            self.assertEqual(guard.status()["state"], "error")

    def test_missing_unit_is_off_not_error(self):
        with patch.object(guard, "unit_info", return_value=info(LoadState="not-found", ActiveState="inactive", MainPID="0")), patch.object(guard, "inhibitors", return_value=[]):
            self.assertEqual(guard.status(), {"state": "off"})

    def test_stray_lock_does_not_claim_off(self):
        with patch.object(guard, "unit_info", return_value=info(LoadState="not-found", ActiveState="inactive", MainPID="0")), patch.object(guard, "inhibitors", return_value=[row()]):
            self.assertEqual(guard.status()["state"], "error")

    def test_refuses_foreign_unit(self):
        text = chr(10).join(k + "=" + v for k, v in info(Description="Someone else").items())
        with patch.object(guard, "command", return_value=subprocess.CompletedProcess([], 0, text, "")):
            with self.assertRaisesRegex(RuntimeError, "different unit"):
                guard.unit_info()

    def test_on_is_idempotent(self):
        with patch.object(guard, "status", return_value={"state": "on", "pid": 123}), patch.object(guard, "command") as cmd:
            self.assertEqual(guard.start()["state"], "on")
            cmd.assert_not_called()

    def test_start_exact_scope_and_no_persistence(self):
        with patch.object(guard, "status", return_value={"state": "off"}), patch.object(guard, "command") as cmd, patch.object(guard, "wait_for", return_value={"state": "on"}):
            guard.start()
            argv = cmd.call_args_list[-1].args[0]
            self.assertEqual(argv[0], "/usr/bin/systemd-run")
            self.assertIn("--what=sleep:handle-lid-switch", argv)
            self.assertIn("--mode=block", argv)
            self.assertIn("--property=PartOf=graphical-session.target", argv)
            self.assertIn("--property=KillMode=control-group", argv)
            self.assertEqual(argv[-2:], ["/usr/bin/sleep", "infinity"])
            self.assertNotIn("enable", argv)
            self.assertNotIn("--what=idle:sleep:shutdown", argv)

    def test_unverified_start_cleans_up(self):
        with patch.object(guard, "status", return_value={"state": "off"}), patch.object(guard, "command") as cmd, patch.object(guard, "wait_for", side_effect=RuntimeError("no lock")):
            with self.assertRaisesRegex(RuntimeError, "no lock"):
                guard.start()
            self.assertEqual(cmd.call_args.args[0], [guard.SYSTEMCTL, "--user", "stop", guard.UNIT])

    def test_off_only_stops_own_unit(self):
        with patch.object(guard, "unit_info", return_value=info()), patch.object(guard, "command") as cmd, patch.object(guard, "wait_for", return_value={"state": "off"}):
            self.assertEqual(guard.stop(), {"state": "off"})
            cmd.assert_called_once_with([guard.SYSTEMCTL, "--user", "stop", guard.UNIT])

    def test_off_is_idempotent(self):
        with patch.object(guard, "unit_info", return_value=info(LoadState="not-found")), patch.object(guard, "command") as cmd, patch.object(guard, "wait_for", return_value={"state": "off"}):
            guard.stop()
            cmd.assert_not_called()

    def test_waits_for_registration(self):
        with patch.object(guard, "status", side_effect=[{"state": "error"}, {"state": "on"}]), patch.object(guard.time, "sleep") as sleep:
            self.assertEqual(guard.wait_for("on"), {"state": "on"})
            sleep.assert_called_once()

    def test_wait_is_bounded(self):
        with patch.object(guard, "status", return_value={"state": "error"}), patch.object(guard.time, "sleep") as sleep:
            with self.assertRaises(RuntimeError):
                guard.wait_for("on")
            self.assertEqual(sleep.call_count, 20)

    def test_error_click_stops_instead_of_starting_another_unit(self):
        with patch.object(guard, "status", return_value={"state": "error"}), patch.object(guard, "stop", return_value={"state": "off"}) as stop:
            guard.operate("toggle")
            stop.assert_called_once()

    def test_commands_are_argv_and_timeout_bounded(self):
        with patch.object(guard.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "ok", "")) as run:
            guard.command(["/usr/bin/true"])
            self.assertEqual(run.call_args.kwargs["timeout"], 5)
            self.assertNotIn("shell", run.call_args.kwargs)


if __name__ == "__main__":
    unittest.main()
