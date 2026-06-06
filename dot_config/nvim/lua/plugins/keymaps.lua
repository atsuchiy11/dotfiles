-- Custom keymaps on top of LazyVim defaults
return {
  {
    "LazyVim/LazyVim",
    init = function()
      -- jj -> ESC (carried over from pre-LazyVim init.vim)
      vim.keymap.set("i", "jj", "<ESC>", { silent = true, desc = "jj to escape" })
    end,
  },
}
