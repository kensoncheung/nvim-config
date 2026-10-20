-- ~/.config/wezterm/wezterm.lua
local wezterm = require 'wezterm';
return {
  font_size = 15.0,
  -- ctrl+- and ctrl+= to change
  -- ctrl+0 to reset
  --
  check_for_updates = false,
  font = wezterm.font_with_fallback {
    { family = "Fantasque Sans Mono", weight = "Regular" },
    { family = "Sarasa Term TC", weight = "Regular" },
    { family = "Noto Sans CJK TC", weight = "Regular" },
    { family = "Noto Color Emoji", weight = "Regular" },
  },
  warn_about_missing_glyphs = false,
  -- color_scheme = "Solarized Dark - Patched",
  -- color_scheme = "Batman",
  line_height = 1.1,
  hide_tab_bar_if_only_one_tab = true,
  use_ime = false,

  -- WhenFollowedBySpace (default), Never, Always
  -- allow_square_glyphs_to_overflow_width = "Never",
  --

  keys = {
    {
      key = 'n',
      mods = 'SHIFT|CTRL',
      action = wezterm.action.ToggleFullScreen,
    }
  },

  window_padding = {
    left = 8,
    right = 8,
    top = 0,
    bottom = 0,
  }
}
