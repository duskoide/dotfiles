#!/usr/bin/env python3
"""Own one transient sleep inhibitor. No root, shell commands, or persistent ON flag."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import time

UNIT = "noctalia-sleep-guard.service"
WHO = "Noctalia Sleep Guard"
DESCRIPTION = "Noctalia Sleep Guard (sleep and lid only)"
WHAT = {"sleep", "handle-lid-switch"}
SYSTEMCTL = "/usr/bin/systemctl"
INHIBIT = "/usr/bin/systemd-inhibit"
RUN = "/usr/bin/systemd-run"


def command(argv, check=True):
    result = subprocess.run(argv, capture_output=True, text=True, timeout=5)
    if check and result.returncode:
        raise RuntimeError((result.stderr or result.stdout or "Command failed").strip())
    return result


def unit_info():
    result = command([SYSTEMCTL, "--user", "show", UNIT,
                      "--property=LoadState,ActiveState,SubState,MainPID,Description,Transient"])
    info = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    if not info.get("LoadState"):
        raise RuntimeError("Could not query the user systemd manager.")
    if info["LoadState"] != "not-found" and (
        info.get("Transient") != "yes" or info.get("Description") != DESCRIPTION
    ):
        raise RuntimeError("A different unit already uses " + UNIT + "; refusing to change it.")
    return info


def inhibitors():
    result = command([INHIBIT, "--list", "--json=short", "--no-pager"])
    rows = json.loads(result.stdout)
    if not isinstance(rows, list):
        raise RuntimeError("Unexpected inhibitor list from systemd.")
    return rows


def matches(row, pid):
    return (row.get("who") == WHO and row.get("uid") == os.getuid()
            and row.get("mode") == "block" and set(row.get("what", "").split(":")) == WHAT
            and row.get("pid") == pid and pid > 0)


def status():
    info = unit_info()
    rows = inhibitors()
    pid = int(info.get("MainPID", "0"))
    own = [r for r in rows if matches(r, pid)]
    running = info.get("ActiveState") in ("active", "activating", "reloading", "deactivating")
    if own and info.get("ActiveState") == "active":
        return {"state": "on", "pid": pid}
    # Never claim OFF if our inhibitor is still present during teardown.
    stray = any(r.get("who") == WHO and r.get("uid") == os.getuid() for r in rows)
    if running or stray:
        return {"state": "error", "error": "Guard unit and inhibitor disagree. Click to stop and retry."}
    return {"state": "off"}


def wait_for(state):
    for _ in range(20):
        result = status()
        if result["state"] == state:
            return result
        time.sleep(0.1)
    raise RuntimeError("Sleep Guard did not reach " + state + ". Check journalctl --user -u " + UNIT)


def stop():
    info = unit_info()
    if info["LoadState"] != "not-found":
        command([SYSTEMCTL, "--user", "stop", UNIT])
    return wait_for("off")


def start():
    current = status()
    if current["state"] == "on":
        return current
    if current["state"] == "error":
        stop()
    # A failed collected transient unit may linger until reset.
    command([SYSTEMCTL, "--user", "reset-failed", UNIT], check=False)
    argv = [RUN, "--user", "--quiet", "--collect", "--unit=" + UNIT,
            "--description=" + DESCRIPTION, "--service-type=exec",
            "--property=PartOf=graphical-session.target", "--property=KillMode=control-group",
            "--property=TimeoutStopSec=3", "--", INHIBIT, "--no-ask-password",
            "--what=sleep:handle-lid-switch", "--mode=block", "--who=" + WHO,
            "--why=Sleep Guard is on; screen blanking remains allowed", "/usr/bin/sleep", "infinity"]
    try:
        command(argv)
        return wait_for("on")
    except (RuntimeError, subprocess.TimeoutExpired):
        # A launched process alone is not proof of a logind lock.
        command([SYSTEMCTL, "--user", "stop", UNIT], check=False)
        raise


def operate(action):
    if action == "status":
        return status()
    if action == "off":
        return stop()
    if action == "on":
        return start()
    if action == "toggle":
        return start() if status()["state"] == "off" else stop()
    raise ValueError("Unknown operation")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("status", "on", "off", "toggle"))
    args = parser.parse_args()
    try:
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/run/user/" + str(os.getuid())))
        if not runtime.is_dir() or runtime.stat().st_uid != os.getuid():
            raise RuntimeError("No user runtime directory; cannot serialize guard operations.")
        # All monitors and the lifecycle cleanup share this lock. No PID-file kills.
        fd = os.open(runtime / "noctalia-sleep-guard.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w") as lock:
            for attempt in range(40):
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if attempt == 39:
                        raise RuntimeError("Another Sleep Guard operation is still running. Try again.")
                    time.sleep(0.1)
            result = operate(args.action)
        print(json.dumps(result))
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({"state": "error", "error": str(exc)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
