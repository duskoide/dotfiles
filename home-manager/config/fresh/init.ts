/// <reference path="./types/fresh.d.ts" />

const editor = getEditor();

const CURSOR_STYLES = {
  block: "\\033[2 q",
  bar: "\\033[6 q",
} as const;

let activeCursorStyle: keyof typeof CURSOR_STYLES | null = null;

function syncViCursor(): void {
  const desired = editor.getEditorMode() === "vi-insert" ? "bar" : "block";
  if (desired === activeCursorStyle) return;

  activeCursorStyle = desired;
  editor.spawnHostProcess("sh", [
    "-c",
    `printf '${CURSOR_STYLES[desired]}' > /dev/tty 2>/dev/null || true`,
  ]);
}

// Keep the cursor static and mode-aware: block outside Insert mode, bar in
// Insert mode. post_command catches every Vi transition while the guard avoids
// spawning a process for ordinary movement or typing.
editor.on("post_command", syncViCursor);

// Workspace restoration includes the explorer's previous visibility. Force it
// open after restore, then return keyboard focus to the editing pane.
editor.on("ready", () => {
  const viMode = editor.getPluginApi("vi-mode");
  if (viMode && !viMode.isEnabled()) viMode.enable();

  // Workspace/chrome restoration can replace the active input context after
  // plugins auto-start. Reassert Normal mode once startup has fully settled.
  if (editor.getEditorMode() !== "vi-normal") {
    editor.setEditorMode("vi-normal");
  }

  editor.executeAction("focus_file_explorer");
  editor.executeAction("focus_editor");
  syncViCursor();
});
