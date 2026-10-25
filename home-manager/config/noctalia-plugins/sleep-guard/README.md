# Sleep Guard

A Noctalia v5 bar button that blocks normal suspend/hibernate requests and
logind lid-close handling, **without inhibiting display blanking or locking**.

## Use

Click **Guard OFF** to turn it on. **Guard ON** is highlighted only after a live
`block` inhibitor is verified; it is not a saved UI flag. Click again to release
it. **Guard !** means verification failed: hover for details, click to stop/retry.
The button refreshes real state every five seconds.

On this Fedora/systemd 262 setup, the inhibitor is:

```text
what=sleep:handle-lid-switch   mode=block
```

It does not acquire `idle`, `shutdown`, a Wayland idle inhibitor, or caffeine.
Normal Noctalia idle/menu suspend and `systemctl suspend` go through logind.
This implementation targets modern systemd (tested on 262), where `block` applies
to same-user requests too; only `block-weak` skips same-user inhibitors. The
matching v262.1 `src/login/logind-inhibit.c` checks that distinction explicitly.
Forced/privileged operations, direct kernel sleep, firmware behavior and
emergency battery actions can bypass inhibitors. This is **not** an absolute
guarantee against every way a machine can sleep or power off.

**Do not put the laptop in a bag with Guard ON**: the machine keeps running
with the lid closed. Monitor battery and cooling; critical-battery behavior was
not tested and should not be relied on to rescue an unattended session.

The existing host file `/etc/systemd/logind.conf.d/99-ignore-lid.conf` already
ignores lid-close on this machine. Turning Guard off does not change that
policy or restore lid-triggered suspend. No system/root configuration is edited.

## Lifetime and recovery

The helper owns only `noctalia-sleep-guard.service`, a **transient user unit**:

- Off after reboot; never enabled as an autostart unit.
- Bound with `PartOf=graphical-session.target`, so stopping that target stops
  it. On this machine the target is bound to `niri.service`, even with user
  lingering enabled. A session that does not stop this target needs manual OFF.
- Normal Noctalia shutdown, plugin disable or uninstall requests cleanup.
- Hot reload preserves protection. Removing one monitor/widget does not stop it.
- An abrupt shell crash cannot run cleanup: protection deliberately remains
  until you turn it off, log out, or stop the unit yourself.

```sh
systemctl --user stop noctalia-sleep-guard.service
systemd-inhibit --list --no-pager --who="Noctalia Sleep Guard"
```

The helper serializes commands across monitors using a lock in
`$XDG_RUNTIME_DIR`; no private task data, ON flag or PID file is stored in Git.
It checks the actual inhibitor PID/UID/type rather than merely a running process.

## Install / commands

From the collection directory, run `python3 install.py` with Noctalia running
(see [collection README](../README.md)). Or register the source manually:

```sh
noctalia msg plugins source add dotfiles path ~/dotfiles/home-manager/config/noctalia-plugins
noctalia msg plugins enable pn/sleep-guard
```

Add `pn/sleep-guard:guard` to a bar. CLI controls for a placed widget:

```sh
noctalia msg plugin pn/sleep-guard:guard focused on
noctalia msg plugin pn/sleep-guard:guard focused off
```

Or invoke `python3 guard.py status|on|off|toggle` directly. The helper uses
standard `/usr/bin` systemd/sleep tools on the host, Python 3 (stdlib only),
and a user systemd manager. Lifecycle cleanup also uses `/usr/bin/flock`.
It never opens an administrator password prompt.

## Tests

From the repository root:

```sh
python3 -m unittest discover -s home-manager/config/noctalia-plugins/sleep-guard/tests -v
nvim --headless -u NONE -l home-manager/config/noctalia-plugins/sleep-guard/tests/widget.lua
noctalia plugins lint home-manager/config/noctalia-plugins/sleep-guard
```

Tests mock subprocesses; live validation should inspect the acquired/released
inhibitor. Do not test by actually suspending the user’s machine unattended.
