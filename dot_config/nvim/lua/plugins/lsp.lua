-- LSP additions on top of LazyVim defaults
return {
  -- gopls config for Go
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          settings = {
            gopls = {
              gofumpt = true,
              staticcheck = true,
              usePlaceholders = true,
              completeUnimported = true,
            },
          },
        },
      },
    },
  },

  -- Ensure mason installs the LSPs and formatters we want
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "gopls",
        "lua-language-server",
        "stylua",
        "shfmt",
      })
    end,
  },
}
