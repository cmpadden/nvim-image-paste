# nvim-image-paste

Paste clipboard images as temporary file paths.

## Installation

Native package manager:

```lua
vim.pack.add({ "https://github.com/cmpadden/nvim-image-paste" })
require("nvim-image-paste").setup()
```

Lazy.nvim:

```lua
{
    "cmpadden/nvim-image-paste",
    opts = {},
}
```

## Usage

Call `require("nvim-image-paste").setup()` to register the command and default mapping.

| Mapping / command | Behavior |
| --- | --- |
| `Ctrl-V` (insert) | Paste clipboard image/file path or text at the cursor |
| `:ImagePaste` | Paste clipboard image/file path or text after the cursor |

To configure without mappings:

```lua
require("nvim-image-paste").setup({ mappings = false, timeout = 5000 })
vim.keymap.set({ "n", "x", "i" }, "<M-v>", function()
    require("nvim-image-paste").paste()
end)
