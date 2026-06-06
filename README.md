# dotfiles

Personal dotfiles for macOS (Apple Silicon), managed with [chezmoi](https://chezmoi.io).

## Bootstrap on a new Mac

Prerequisite: Xcode Command Line Tools (`xcode-select --install`).

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply atsuchiy11
```

This will:

1. Install chezmoi
2. Clone this repo into `~/.local/share/chezmoi/`
3. Prompt for `name`, `email`, `github_user`, `is_work_machine`
4. Run `run_once_before_install-packages.sh` (Homebrew + Brewfile + mise install)
5. Apply all `dot_*` files to `~/`

Then open Warp and run `nvim` once — LazyVim will install plugins on first launch.

## Components

See `docs/superpowers/specs/2026-06-06-warp-lazyvim-tui-env-design.md` for the architecture.

## Verification

Last verified on 2026-06-06 on macOS (Apple Silicon).
Acceptance checklist (see `docs/superpowers/plans/...`) passed:
starship prompt, zsh-autosuggestions, atuin history search, zoxide,
eza/bat, git-delta, lazygit, LazyVim + telescope, mise, `chezmoi verify`.
