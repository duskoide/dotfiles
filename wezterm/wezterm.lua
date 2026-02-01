local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.font_size = 16
config.font = wezterm.font("Iosevka")

config.colors = {
	cursor_bg = "white",
}

config.enable_wayland = true
config.window_decorations = "NONE"

return config
