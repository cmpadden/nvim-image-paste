# nvim-image-paste

Paste clipboard images as temporary file paths. Requires Neovim 0.10+;
there is no dependency on Node or a Neovim plugin manager.

## Installation

With lazy.nvim:

```lua
{
    "cmpadden/nvim-image-paste",
    opts = {},
}
```

With Neovim 0.12+'s native package manager:

```lua
vim.pack.add({ "https://github.com/cmpadden/nvim-image-paste" })
require("nvim-image-paste").setup()
```

For local development (no package manager or Git clone step inside Neovim):

```lua
vim.opt.runtimepath:prepend(vim.fn.expand("~/src/nvim-image-paste"))
require("nvim-image-paste").setup()
```

## Usage

Call `require("nvim-image-paste").setup()` to register the command and default mapping.

| Mapping / command | Behavior |
| --- | --- |
| `Ctrl-V` (insert) | Paste clipboard image/file path or text at the cursor |
| `:ImagePaste` | Paste clipboard image/file path or text after the cursor |

To configure without installing mappings:

```lua
require("nvim-image-paste").setup({ mappings = false, timeout = 5000 })
vim.keymap.set({ "n", "x", "i" }, "<M-v>", function()
    require("nvim-image-paste").paste()
end)
