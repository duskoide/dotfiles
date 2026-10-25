#!/usr/bin/env python3
"""Register both local plugins and add bar widgets without replacing other settings."""
import argparse
import copy
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import tomllib

WIDGETS = {"project-tasks": "pn/project-tasks:tasks", "sleep-guard": "pn/sleep-guard:guard"}
SOURCE = Path(__file__).resolve().parent


def run(*args):
    p = subprocess.run(["noctalia", *args], text=True, capture_output=True, timeout=15)
    if p.returncode or p.stdout.strip().startswith("error:"):
        raise RuntimeError((p.stderr or p.stdout).strip())
    return p.stdout


def state_path():
    root = os.environ.get("NOCTALIA_STATE_HOME")
    if not root:
        root = str(Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "noctalia")
    return Path(root).expanduser() / "settings.toml"


def section_range(lines, section):
    matches = [i for i, line in enumerate(lines) if line.strip() == "[" + section + "]"]
    if len(matches) > 1:
        raise ValueError("Duplicate section: " + section)
    if not matches:
        return None
    first = matches[0]
    last = next((i for i in range(first + 1, len(lines)) if lines[i].lstrip().startswith("[")), len(lines))
    return first, last


def transform(text, effective):
    """Only bar.default.start and missing widget types may change; prove this."""
    original = tomllib.loads(text)
    expected = copy.deepcopy(original)
    lines = text.splitlines(keepends=True)
    # A custom bar order needs a deliberate choice rather than an unused default.
    bars = effective.get("bar", {})
    if bars.get("order") and "default" not in bars["order"]:
        raise ValueError("Custom bar order: add the two widgets in Settings → Bar instead.")
    start = original.get("bar", {}).get("default", {}).get("start")
    if start is None:
        start = bars.get("default", {}).get("start")
    if not isinstance(start, list) or not all(isinstance(x, str) for x in start):
        raise ValueError("Cannot determine default bar start widgets; configure the bar first.")
    new_start = start + [name for name in WIDGETS if name not in start]
    section = section_range(lines, "bar.default")
    if new_start != start or original.get("bar", {}).get("default", {}).get("start") is None:
        assignment = "start = " + json.dumps(new_start, ensure_ascii=False) + chr(10)
        if section:
            first, last = section
            indices = [i for i in range(first + 1, last) if re.match(r"^\s*start\s*=", lines[i])]
            if indices:
                i = indices[0]
                # Do not mis-edit multiline values, comments or alternative key syntax.
                try:
                    single = tomllib.loads(lines[i])
                except tomllib.TOMLDecodeError as exc:
                    raise ValueError("Multiline start array: format it on one line or add widgets manually.") from exc
                if single.get("start") != start:
                    raise ValueError("Unsupported start array syntax; add widgets manually.")
                lines[i] = assignment
            else:
                if "start" in original.get("bar", {}).get("default", {}):
                    raise ValueError("Unsupported start key syntax; add widgets manually.")
                lines.insert(last, assignment)
        else:
            if original.get("bar", {}).get("default"):
                raise ValueError("Unsupported inline/dotted bar table; use Settings → Bar.")
            lines.extend([chr(10), "[bar.default]" + chr(10), assignment])
        expected.setdefault("bar", {}).setdefault("default", {})["start"] = new_start
    result = "".join(lines)
    for name, kind in WIDGETS.items():
        current = effective.get("widget", {}).get(name)
        local = original.get("widget", {}).get(name)
        current = local if local is not None else current
        if current is not None:
            if current.get("type") != kind:
                raise ValueError("Widget name conflict: " + name)
            continue
        result += chr(10) + "[widget." + name + "]" + chr(10) + "type = " + json.dumps(kind) + chr(10)
        expected.setdefault("widget", {})[name] = {"type": kind}
    if tomllib.loads(result) != expected:
        raise ValueError("Refusing an edit that would alter unrelated settings.")
    return result


def source_present(output):
    for line in output.splitlines():
        parts = line.split(maxsplit=2)
        if parts and parts[0] == "dotfiles":
            if len(parts) != 3 or parts[1] != "path" or Path(parts[2]).expanduser().resolve() != SOURCE:
                raise ValueError("A different 'dotfiles' plugin source exists. Rename it explicitly first.")
            return True
    return False


def enabled_ids(output):
    return {line.split()[0] for line in output.splitlines() if " enabled" in line}


def atomic_settings(path, original, candidate):
    if candidate == original:
        return None
    if path.is_symlink():
        raise ValueError("Settings is a symlink; edit its source instead of replacing it.")
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".noctalia-plugins-", suffix=".toml", dir=path.parent)
    temporary = Path(tmp)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(candidate)
            stream.flush()
            os.fsync(stream.fileno())
        run("config", "validate", str(temporary))
        actual = path.read_text() if path.exists() else ""
        if actual != original:
            raise ValueError("Settings changed while preparing the edit. Rerun the installer.")
        backup = None
        if path.exists():
            backup = path.with_name("settings.toml.before-local-plugins-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
            shutil.copy2(path, backup)
            backup.chmod(0o600)
        os.replace(temporary, path)
        return backup
    finally:
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Preview required changes without applying them")
    args = parser.parse_args()
    try:
        path = state_path()
        if path.is_symlink():
            raise ValueError("Host settings is a symlink; manage its source instead.")
        original = path.read_text() if path.exists() else ""
        effective = tomllib.loads(run("config", "export", "full"))
        candidate = transform(original, effective)  # preflight before any live changes
        has_source = source_present(run("msg", "plugins", "source", "list"))
        active = enabled_ids(run("msg", "plugins", "list"))
        missing = [kind.split(":")[0] for kind in WIDGETS.values() if kind.split(":")[0] not in active]
        if args.check:
            print("Source:", "already registered" if has_source else "would register " + str(SOURCE))
            print("Plugins:", "already enabled" if not missing else "would enable " + ", ".join(missing))
            print("Bar:", "already configured" if candidate == original else "would add missing local widgets")
            return 0
        if not has_source:
            print(run("msg", "plugins", "source", "add", "dotfiles", "path", str(SOURCE)).strip())
        for plugin in missing:
            print(run("msg", "plugins", "enable", plugin).strip())
        if missing or not has_source:
            # IPC enabling may finish asynchronously. No full shell restart needed.
            for _ in range(20):
                if all(kind.split(":")[0] in enabled_ids(run("msg", "plugins", "list")) for kind in WIDGETS.values()):
                    break
                time.sleep(0.1)
            else:
                raise RuntimeError("Plugin enable did not complete; inspect Noctalia logs and rerun.")
            original = path.read_text() if path.exists() else ""
            effective = tomllib.loads(run("config", "export", "full"))
            candidate = transform(original, effective)
        if candidate != original:
            backup = atomic_settings(path, original, candidate)
            print("Settings backup:", backup or "new settings file")
            print(run("msg", "config-reload").strip())
        else:
            print("Bar already configured; no settings edit or reload needed.")
        print("Both plugins configured. Sleep Guard blocking state is unchanged.")
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("Install failed: " + str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
