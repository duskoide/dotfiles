# Project Tasks

A local Noctalia v5 plugin: project-grouped tasks with **To Do**, **In Progress**,
**Blocked**, and **Done** statuses, optional local date/time deadlines, and
optional links to documents or tickets.
Requires plugin API 24+ and `xdg-open`. Built for Noctalia v5.3.0.

## Install

Register the collection directory, not the individual plugin directory:

```sh
noctalia msg plugins source add dotfiles path ~/dotfiles/home-manager/config/noctalia-plugins
noctalia msg plugins enable pn/project-tasks
```

Home Manager also declares `~/.config/noctalia-plugins` as an out-of-store link
to this collection; after your next switch, that path can be used instead.
Source registration and bar placement remain Noctalia-managed, not overwritten
by Home Manager. Path sources hot-reload script changes.

Add **Project Tasks** (`pn/project-tasks:tasks`) from **Settings → Bar**. Click it
to open the task panel, or run:

```sh
noctalia msg panel-toggle pn/project-tasks:panel
```

## Use

- **New task**: enter a title, project name, status, and optionally a deadline
  and a full `https://` or `http://` URL. Empty project names become **Inbox**.
- Deadlines use separate **Date (`YYYY-MM-DD`)** and **Time (`HH:MM`, 24-hour)**
  fields. Enter both or leave both blank. They are stored as local wall-clock
  time, not a synced calendar event; no reminders or timezone conversion are
  provided. Real calendar dates and valid hours/minutes are checked on save.
- Projects are derived from tasks: type a new project name when adding/editing
  a task. A project disappears when its last task is moved or deleted.
- The project dropdown filters the list; **All projects** groups it by project.
- Change status directly with the task row dropdown. The bar counts all tasks
  not marked **Done**, including **Blocked** tasks.
- **↗** opens the link in your default browser. A blank link disables the button.
  URLs are passed as a single argument, never interpreted as shell commands.
- The pencil edits a task; the trash button asks for confirmation.
- **Save task** commits edits. **Cancel** discards the draft. Escape/Close keeps
  the draft in memory until the plugin reloads; unsaved drafts are not durable.
- Links are references only. Google Docs, issue trackers, etc. do **not** sync
  task status automatically.

## Data and recovery

`tasks.json` lives in Noctalia’s per-plugin `noctalia.pluginDataDir()`, outside
the checkout: normally `~/.local/state/noctalia/plugins/data/pn/project-tasks/`.
The directory follows `NOCTALIA_STATE_HOME` if set. The panel is
the only writer. Each save checks for external changes, writes a sibling temp
file, then renames it over the original. `tasks.json.bak` keeps the previous
valid contents. No data file is created until the first saved task.

An unreadable, malformed, or unsupported-version file disables editing instead
of replacing your tasks. Disable the plugin before manually editing/restoring
its data, preserve the damaged file, restore `tasks.json.bak` to `tasks.json`,
and enable the plugin again. The bar reads saved data on startup and receives
updates from panel saves; external file edits require reopening the panel or
re-enabling the plugin.

Version 1 data shape:

```json
{
  "version": 1,
  "nextId": 2,
  "tasks": [
    {"id": 1, "title": "Write proposal", "project": "Website", "status": "doing", "url": "https://docs.google.com/", "deadline": "2027-12-31T18:45"}
  ]
}
```

The `deadline` field is optional and omitted deadlines load as blank, so files
created before deadline support remain compatible without a data rewrite.

## Tests

The scripts deliberately use Lua-compatible syntax so model and callback tests
can run in Neovim’s LuaJIT with a mocked Noctalia host, without touching real
task data or opening a browser. From the repository root:

```sh
nvim --headless -u NONE -l home-manager/config/noctalia-plugins/project-tasks/tests/run.lua
noctalia plugins lint home-manager/config/noctalia-plugins/project-tasks
```

Real rendering and host compatibility must also be checked in Noctalia.

## Host caveat

During development on `v5.3.0 (ce0e90c)`, Noctalia crashed in its native
`Node::addChild` code during close/disable/source-removal of a temporary test
plugin. The cause is not established; normal panel use and reopening worked.
Avoid repeated reload/teardown cycles on this build. If the shell exits, restart
it with `niri msg action spawn -- noctalia`.

## Disable / remove

```sh
noctalia msg plugins disable pn/project-tasks
```

Remove the widget from the bar. Remove the `dotfiles` source only if you no
longer use any plugins from this collection. Keep or separately delete the
plugin’s state directory; disabling the plugin does not intentionally erase
your tasks.
