# Local Noctalia plugins

This collection is tracked in the dotfiles repository:

- [Project Tasks](project-tasks/README.md): grouped projects, task statuses and
  document/ticket URLs; widget `pn/project-tasks:tasks`.
- [Sleep Guard](sleep-guard/README.md): sleep/lid inhibition without keeping the
  display awake; widget `pn/sleep-guard:guard`.

Home Manager declares an out-of-store link from `~/.config/noctalia-plugins`
to this directory. The running setup can use this checkout path directly before
your next Home Manager switch. Noctalia’s main settings remain host-managed.

## Reproduce the setup

With Noctalia v5 running:

```sh
cd ~/dotfiles/home-manager/config/noctalia-plugins
python3 install.py --check
python3 install.py
```

The installer registers the collection as the `dotfiles` path source, enables
both plugins and appends their widgets to the default bar. It preserves existing
settings/widgets, validates the edited TOML and saves a timestamped backup. It
is safe to rerun; conflicts are errors rather than permission to overwrite.
Run it once on a new machine: bootstrap/Home Manager alone does not perform
live Noctalia IPC or edit host-owned bar settings.

Enabling the **Sleep Guard plugin** only adds the button; sleep blocking stays
OFF until you click it. No plugin runtime state is restored by this installer.

Task data and its backup live outside Git under
`~/.local/state/noctalia/plugins/data/pn/project-tasks/` (or Noctalia’s configured
state root). The collection `.gitignore` also excludes accidental task JSON and
Python bytecode. Never symlink task data into this source collection.

## All tests

From the repository root:

```sh
python3 -m unittest discover -s home-manager/config/noctalia-plugins/tests -v
python3 -m unittest discover -s home-manager/config/noctalia-plugins/sleep-guard/tests -v
nvim --headless -u NONE -l home-manager/config/noctalia-plugins/project-tasks/tests/run.lua
nvim --headless -u NONE -l home-manager/config/noctalia-plugins/sleep-guard/tests/widget.lua
noctalia plugins lint home-manager/config/noctalia-plugins/project-tasks home-manager/config/noctalia-plugins/sleep-guard
```
