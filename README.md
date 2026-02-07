# luabuff.nvim

A plugin which must be used in conjunction with lualine. This displays buffers with visual separators, and allows pinning support, diagnostic indicators, git status, and smart scrolling.

https://github.com/user-attachments/assets/bd047d73-7b07-42e1-8728-9e5ac07d4235

## ✨ Features

- **Buffer Pinning**: Pin frequently used buffers to keep them at the front
- **Visual Separators**: Beautiful separators with dynamic highlighting
- **Diagnostic Integration**: Shows buffer diagnostics with color coding
- **Git Status**: Displays git changes (works with gitsigns.nvim)
- **Smart Scrolling**: Shows limited buffers with scroll indicators
- **Clickable Buffers**: Click to switch between buffers
- **Position-based Navigation**: Navigate buffers by visual position
- **Buffer Management**: Delete buffers to left/right with keymaps
- **Modified Indicators**: Visual indication of unsaved changes

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  name = "luabuff",
  dir = vim.fn.stdpath("config") .. "/lua/luabuff",
  lazy = false,
  priority = 1000,
  config = function()
    require("luabuff").setup({
      max_visible_buffers = 6,
      active_separators = "",
      inactive_separators = "╲",
      pin_icon = "📌",
      modified_icon = "●",
    })
  end,
}
```

## 🔧 Configuration

### Default Configuration

```lua
require("luabuff").setup({
  max_visible_buffers = 6,        -- Maximum number of buffers to show at once
  active_separators = "",       -- Separator for active buffer (powerline style)
  inactive_separators = "╲",      -- Separator for inactive buffers
  pinned_key = "LuaBuffPinnedBuffers", -- vim.g key for storing pinned buffers
  pin_icon = "📌",                -- Icon shown for pinned buffers
  modified_icon = "●",            -- Icon shown for modified buffers
  updatetime = 1000,              -- Update frequency in milliseconds
})
```

### Configuration Options

| Option                | Type   | Default                  | Description                                 |
| --------------------- | ------ | ------------------------ | ------------------------------------------- |
| `max_visible_buffers` | number | `6`                      | Maximum buffers shown before scrolling      |
| `active_separators`   | string | `""`                     | Separator character(s) for active buffer    |
| `inactive_separators` | string | `"╲"`                    | Separator character(s) for inactive buffers |
| `pinned_key`          | string | `"LuaBuffPinnedBuffers"` | Key for storing pinned buffer state         |
| `pin_icon`            | string | `"📌"`                   | Icon displayed next to pinned buffers       |
| `modified_icon`       | string | `"●"`                    | Icon displayed next to modified buffers     |
| `updatetime`          | number | `1000`                   | Cache refresh interval in milliseconds      |

## 🎨 Lualine Integration

Add luabuff to your lualine configuration:

### Basic Setup

```lua
require('lualine').setup({
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {
      {
        function()
          return require('luabuff').get_buffers()
        end,
        separator = '',
      }
    },
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
})
```

## ⌨️ Default Keymaps

The plugin automatically sets up the following keymaps:

| Keymap             | Action           | Description                             |
| ------------------ | ---------------- | --------------------------------------- |
| `<M-s>`            | Previous buffer  | Navigate to previous buffer by position |
| `<M-f>`            | Next buffer      | Navigate to next buffer by position     |
| `<A-1>` to `<A-6>` | Go to buffer 1-6 | Jump directly to buffer at position     |
| `<leader>bp`       | Toggle pin       | Pin/unpin current buffer                |
| `<leader>bl`       | Delete left      | Delete all buffers to the left          |
| `<leader>br`       | Delete right     | Delete all buffers to the right         |

### Custom Keymaps

You can disable automatic keymaps and set your own:

```lua
-- Access functions directly
vim.keymap.set('n', '<your-key>', function()
  require('luabuff').goto_next_buffer()
end, { desc = 'Next buffer' })

vim.keymap.set('n', '<your-key>', function()
  require('luabuff').toggle_pin_current()
end, { desc = 'Toggle pin buffer' })

-- Move buffer order (reorder buffers in the bufferline)
vim.keymap.set('n', '<C-h>', function()
  require('luabuff').move_buffer(-1)
end, { desc = 'Move buffer left' })

vim.keymap.set('n', '<C-l>', function()
  require('luabuff').move_buffer(1)
end, { desc = 'Move buffer right' })
```

## 🎯 Functions

### Public API

| Function                            | Description                                    |
| ----------------------------------- | ---------------------------------------------- |
| `get_buffers()`                     | Returns formatted buffer string for lualine    |
| `goto_next_buffer()`                | Navigate to next buffer by position            |
| `goto_previous_buffer()`            | Navigate to previous buffer by position        |
| `toggle_pin_current()`              | Toggle pin status of current buffer            |
| `move_buffer(direction)`            | Move current buffer left (-1) or right (1)     |
| `get_buffer_by_position(pos)`       | Get buffer number at specific position         |
| `switch_to_buffer_by_position(pos)` | Switch to buffer at position (used for clicks) |

## 🎨 Highlight Groups

luabuff uses the following highlight groups that you can customize:

### Buffer States

- `lualine_buffer_normal` - Active buffer
- `lualine_buffer_inactive` - Inactive buffer
- `LualineBufferVisible` - Buffer visible in a window
- `LualineBufferPinned` - Pinned buffer
- `LualineBufferActivePinned` - Active pinned buffer

### Diagnostics

- `LualineBufferError` / `LualineBufferActiveError`
- `LualineBufferWarn` / `LualineBufferActiveWarn`
- `LualineBufferInfo` / `LualineBufferActiveInfo`
- `LualineBufferHint` / `LualineBufferActiveHint`

### Git Status

- `LualineBufferGitAdded` / `LualineBufferActiveGitAdded`
- `LualineBufferGitChanged` / `LualineBufferActiveGitChanged`
- `LualineBufferGitDeleted` / `LualineBufferActiveGitDeleted`

### UI Elements

- `LualineBufferSeparator` - Inactive buffer separators
- `LualineBufferScrollIndicator` - Scroll indicators

## 🔧 Advanced Usage

### Buffer Filtering

The plugin automatically filters buffers to show only listed and valid buffers. Pinned buffers always appear first in the order.

## 🙏 Credits

Inspired by [akinsho/bufferline.nvim](https://github.com/akinsho/bufferline.nvim) - Thanks for the excellent buffer management concepts and design patterns that helped shape this plugin.
