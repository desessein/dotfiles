-- You can configure your bookmarks by lua language
local bookmarks = {}

local path_sep = package.config:sub(1, 1)
local home_path = ya.target_family() == "windows" and os.getenv("USERPROFILE") or os.getenv("HOME")
if ya.target_family() == "windows" then
  table.insert(bookmarks, {
    tag = "Scoop Local",
    
    path = (os.getenv("SCOOP") or home_path .. "\\scoop") .. "\\",
    key = "p"
  })
  table.insert(bookmarks, {
    tag = "Scoop Global",
    path = (os.getenv("SCOOP_GLOBAL") or "C:\\ProgramData\\scoop") .. "\\",
    key = "P"
  })
end
table.insert(bookmarks, {
  tag = "Desktop",
  path = home_path .. path_sep .. "Desktop" .. path_sep,
  key = "d"
})

require("yamb"):setup {
  -- Optional, the path ending with path seperator represents folder.
  bookmarks = bookmarks,
  -- Optional, recieve notification everytime you jump.
  jump_notify = true,
  -- Optional, the cli of fzf.
  cli = "fzf",
  -- Optional, a string used for randomly generating keys, where the preceding characters have higher priority.
  keys = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
  -- Optional, the path of bookmarks
  path = (ya.target_family() == "windows" and os.getenv("APPDATA") .. "\\yazi\\config\\bookmark") or
        (os.getenv("HOME") .. "/.config/yazi/bookmark"),
}

-- Git status integration
require("git"):setup()

-- Zoxide integration for smart directory jumping
-- Press 'z' in Yazi to jump to frequently visited directories
require("zoxide"):setup {
  update_db = true,  -- Update zoxide database when changing directories
}

-- Projects plugin - save/restore workspace sessions
-- Keybindings: P+s (save), P+l (load), P+P (load last)
require("projects"):setup({
  save = {
    method = "lua",  -- Use lua method for better cross-platform support
  },
  last = {
    update_after_save = true,
    update_after_load = true,
    load_after_start = false,  -- Don't auto-load on start
  },
  notify = {
    enable = true,
    title = "Projects",
    timeout = 3,
    level = "info",
  },
})

-- Bunny bookmarks - Persistent and ephemeral hops
-- Press ';' to open menu, create temporary bookmarks during session
require("bunny"):setup({
  hops = {
    { key = "~", path = "~", desc = "Home" },
    { key = "c", path = "~/.config", desc = "Config" },
    { key = "d", path = "~/Desktop", desc = "Desktop" },
    { key = "D", path = "~/Downloads", desc = "Downloads" },
    { key = "p", path = "~/projects", desc = "Projects" },
    { key = "/", path = "/", desc = "Root" },
    { key = "t", path = "/tmp", desc = "Temp" },
  },
  desc_strategy = "path",
  ephemeral = true,  -- Enable temporary session-only bookmarks
  tabs = true,       -- Can hop to directories from other tabs
  notify = true,     -- Show notification after hopping
  fuzzy_cmd = "fzf",
})

-- Copy file contents plugin - Copy file contents to clipboard
require("copy-file-contents"):setup({
  append_char = "\n",
  notification = true,
})

-- Relative motions plugin - Vim-style motions with relative line numbers
require("relative-motions"):setup({
  show_numbers = "relative",  -- Show relative line numbers
  show_motion = true,          -- Show current motion in status bar
  only_motions = false,        -- Enable all operations (yank, delete, etc.)
  enter_mode = "first",        -- Enter folder method
})
