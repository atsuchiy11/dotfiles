# dotfiles maintenance recipes
# Run from the chezmoi source dir (~/.ghq/github.com/atsuchiy11/dotfiles)

# Default: list all recipes
default:
    @just --list

# Show pending changes between source and ~/
diff:
    chezmoi diff

# Apply with interactive prompts on conflicts
apply:
    chezmoi apply --interactive

# Verify source and destination are in sync (exits non-zero on drift)
verify:
    chezmoi verify

# Show what files chezmoi manages
managed:
    chezmoi managed

# Open the source dir in a subshell
cd:
    chezmoi cd

# Static checks (shell, zsh syntax, lua)
lint:
    @echo "▶ shellcheck"
    -find . -type f \( -name '*.sh' -o -name 'run_once_*' \) -not -path './dot_config/nvim/*' -print0 \
        | xargs -0 -r shellcheck 2>&1 | head -50
    @echo "▶ zsh -n dot_zshrc"
    zsh -n dot_zshrc
    @echo "▶ stylua --check (dot_config/nvim/lua)"
    -stylua --check dot_config/nvim/lua 2>&1 | head -30
    @echo "✅ lint done"

# Update brew packages declared in Brewfile
brew-upgrade:
    brew update
    brew bundle --file=./Brewfile
    brew bundle cleanup --file=./Brewfile --force

# Simulate bootstrap on a fresh Linux container (skips Brewfile via .chezmoiignore)
test-bootstrap:
    docker run --rm -v $(pwd):/dotfiles ubuntu:22.04 bash -c "\
        apt-get update -qq && \
        apt-get install -y -qq curl git zsh ca-certificates && \
        sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- init --apply --source=/dotfiles"

# Push any pending commits
push:
    chezmoi git -- push
