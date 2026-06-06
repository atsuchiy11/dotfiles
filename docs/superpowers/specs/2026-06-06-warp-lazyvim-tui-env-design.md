# Warp + LazyVim TUI 開発環境 設計書

- **作成日**: 2026-06-06
- **対象**: 個人 Mac (Apple Silicon, macOS) の TUI 開発環境を chezmoi 管理の dotfiles として再構築する
- **状態**: 設計確定、実装計画 (writing-plans) 待ち

## 1. 目的とスコープ

### 1.1 目的

Warp.app をターミナル UI の中心に据え、その内部で動かす TUI 開発環境（zsh + Neovim/LazyVim を主軸とした CLI ツール群）を、chezmoi で管理する dotfiles リポジトリとして構築する。

新しい Mac を入手したとき、`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <github-user>` の一発で開発環境が復元できる状態を目指す。

### 1.2 スコープに含むもの

- Warp と中身（shell、prompt、エディタ、CLI ツール群）の構成
- chezmoi 管理の dotfiles リポジトリ構造
- 既存環境 → chezmoi 化への段階的移行手順
- 新規 Mac での bootstrap フロー
- 検証手段（ローカル、Docker、CI、受け入れチェック）

### 1.3 スコープに含まないもの

- Nix / nix-darwin / home-manager の導入（明示的に不採用）
- multiplexer (tmux/zellij) の導入（明示的に不採用、Warp 標準機能で代替）
- Zed の詳細な設定（既存利用継続、本ドキュメントの主対象外）
- プロジェクト単位の devshell（別途 `flake.nix` で管理する既存方針を継続）
- secrets / API キーの暗号化詳細（chezmoi `--encrypt` の運用フローは別 spec）

## 2. 前提と既存環境

### 2.1 ハードウェア / OS

- Apple Silicon Mac
- macOS (Darwin 25.5.0)
- Xcode Command Line Tools インストール済み

### 2.2 既存インストール

- Warp.app (Cask)
- Zed.app (Cask、`~/.config/zed/` あり)
- Homebrew 5.1.13
- Nix 2.34.6 (Determinate Systems installer、Flakes 有効、本設計では不使用)
- zsh (`~/.zshrc` 6KB カスタム済み、`~/.zprofile` 599B)
- Neovim (`~/.config/nvim/init.vim` 169B、ほぼ空)
- mise (`~/.config/mise/` 設定済み)
- fzf
- gh (`~/.config/gh/` 設定済み、認証情報含む)

### 2.3 既存に存在しないもの

- chezmoi 等の dotfiles 管理ツール
- starship、sheldon、atuin、zoxide、ripgrep、fd、lazygit、delta、eza、bat
- LazyVim
- dotfiles 用 git リポジトリ

## 3. 全体アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│ Warp.app  ── GUI レイヤー (blocks, AI, palette, split, tabs)│
└────────────────────────────┬────────────────────────────────┘
                             │ 起動
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ zsh + starship ── shell レイヤー                             │
│   ├─ sheldon (zsh プラグイン管理)                           │
│   ├─ atuin (history)                                        │
│   ├─ zoxide (cd 強化)                                       │
│   └─ mise (ランタイム切り替え) ← 既存                       │
└────────────────────────────┬────────────────────────────────┘
                             │ `nvim` / `lazygit` 等
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ TUI アプリケーション層                                       │
│   ├─ Neovim (LazyVim) ← 主役                                │
│   ├─ lazygit (git TUI)                                      │
│   ├─ fzf (fuzzy finder) ← 既存                              │
│   └─ ripgrep / fd / bat / eza (検索・閲覧)                  │
└─────────────────────────────────────────────────────────────┘

全部 chezmoi で管理した dotfiles から source される
~/.local/share/chezmoi/  ← git リポ本体
       │
       └─ chezmoi apply → ~/.zshrc, ~/.config/nvim/, etc.
```

### 3.1 設計の3本柱

1. **Warp が UI、shell より下は再利用可能**
   Warp 固有の設定は最小限に留め、shell 以下は他のターミナル (SSH 先、iTerm 等) でも同じ体験になるようにする。
2. **LazyVim の規約に乗る**
   自前で全部書くのではなく、LazyVim の `lua/plugins/*.lua` を追加・override する形で extend。アップデートで壊れにくい。
3. **chezmoi の `run_once_` script で bootstrap**
   新 Mac で `chezmoi init` 一発で Homebrew インストール → ツール群 install → LazyVim 初回起動準備まで自動。

### 3.2 Warp の特性と回避ポイント

Warp の "blocks" ベース UI は shell コマンド入力中は強力だが、Neovim のようなフルスクリーン TUI に入ると事実上無効化される。本設計はこの前提を許容し、以下のように扱う:

| 状態 | Warp 機能 | 本設計の扱い |
|------|-----------|------------|
| shell コマンド入力中 | blocks, AI, palette が有効 | そのまま活用 |
| エディタ起動中 | blocks 無効、Warp はレンダラのみ | LazyVim 内で完結 |
| Warp 内分割・タブ | tmux 不要、Warp 標準で十分 | multiplexer なしの方針 |

衝突回避の具体設定:
- Warp の "Subshell detection" は OFF にする (starship と二重装飾しないため)
- Warp の history と atuin は併存させる (両者の機構は独立)

## 4. コンポーネント詳細

### 4.1 インストール対象一覧

| 役割 | ツール | 状態 | 備考 |
|------|--------|------|------|
| ターミナル | Warp | 既存 | Cask 管理のまま、Brewfile に宣言だけ追加 |
| shell | zsh | 既存 | macOS 標準、`.zshrc` 整理対象 |
| prompt | starship | 新規 | Warp の subshell 装飾は OFF |
| zsh プラグイン管理 | sheldon | 新規 | TOML 宣言、起動高速 |
| history | atuin | 新規 | SQLite、Mac 横断履歴 (将来) |
| ディレクトリジャンプ | zoxide | 新規 | `z dirname` |
| エディタ | Neovim | 既存 | LazyVim を被せる |
| エディタ配布 | LazyVim | 新規 | `~/.config/nvim/` 配下 |
| 検索 (grep) | ripgrep | 新規 | telescope が要求 |
| 検索 (find) | fd | 新規 | telescope が要求 |
| fuzzy finder | fzf | 既存 | telescope と併用 |
| git TUI | lazygit | 新規 | LazyVim 内から `<leader>gg` |
| git diff | delta | 新規 | `git diff` 表示強化 |
| GitHub CLI | gh | 既存 | PR/issue 操作 |
| ls 強化 | eza | 新規 | git 状態カラー付き |
| cat 強化 | bat | 新規 | シンタックスハイライト |
| ランタイム | mise | 既存 | Go/Node/Python |
| dotfiles 管理 | chezmoi | 新規 | 母体 |
| 補助エディタ | Zed | 既存 | Cask、本設計では設定変更なし |

新規 brew 導入: **11 個** (starship, sheldon, atuin, zoxide, ripgrep, fd, lazygit, git-delta, eza, bat, chezmoi)。

### 4.2 LazyVim 構成方針

- LazyVim starter (`https://github.com/LazyVim/starter`) を clone して `~/.config/nvim/` に配置
- starter リポの `.git` は削除し、chezmoi 側で管理
- 自分のカスタムは `~/.config/nvim/lua/plugins/*.lua` に **プラグイン追加 or override** として書く
- 最小カスタム:
  - `lua/plugins/keymaps.lua`: `jj` → ESC マップ（既存設定継承）
  - `lua/plugins/colorscheme.lua`: tokyonight などをデフォルトに
  - `lua/plugins/lsp.lua`: gopls 等を mason 経由で追加

### 4.3 補助エディタ Zed の扱い

- 既存 `~/.config/zed/` は触らない
- 将来必要になれば keybind や colorscheme の同期を別 spec で扱う

## 5. dotfiles リポジトリ構造

chezmoi の source ディレクトリ (`~/.local/share/chezmoi/`) 配下:

```
~/.local/share/chezmoi/                          ← git リポ本体
├── .chezmoiroot                                 ← 空ファイル、root マーカー
├── .chezmoiignore                               ← 除外設定
├── .chezmoi.toml.tmpl                           ← 初回 init 時のテンプレ
├── README.md
├── Brewfile                                     ← brew bundle 用
├── justfile                                     ← 検証コマンド集約
├── .github/workflows/ci.yml                     ← CI
│
├── dot_zshrc                                    → ~/.zshrc
├── dot_zprofile                                 → ~/.zprofile
├── dot_zshenv                                   → ~/.zshenv (新規作成)
│
├── dot_config/
│   ├── starship.toml                            → ~/.config/starship.toml
│   ├── sheldon/plugins.toml                     → ~/.config/sheldon/plugins.toml
│   ├── atuin/config.toml                        → ~/.config/atuin/config.toml
│   ├── git/config                               → ~/.config/git/config
│   ├── git/ignore                               → ~/.config/git/ignore
│   ├── nvim/                                    → ~/.config/nvim/ (LazyVim 一式)
│   │   ├── init.lua
│   │   ├── lazy-lock.json
│   │   ├── lua/config/{autocmds,keymaps,lazy,options}.lua
│   │   ├── lua/plugins/{colorscheme,lsp,keymaps}.lua  ← 自分のカスタム
│   │   ├── stylua.toml
│   │   └── .neoconf.json
│   ├── mise/config.toml                         → ~/.config/mise/config.toml
│   └── lazygit/config.yml                       → ~/.config/lazygit/config.yml
│
├── private_dot_ssh/
│   └── config.tmpl                              → ~/.ssh/config (パーミッション 700)
│
└── run_once_before_install-packages.sh.tmpl     ← bootstrap script
```

### 5.1 chezmoi 命名規則

| プレフィックス | 意味 |
|--------------|------|
| `dot_` | `.` で始まるファイル |
| `private_` | パーミッション 600/700 |
| `executable_` | 実行ビット付与 |
| `.tmpl` 拡張子 | Go template 展開 |
| `run_once_` | 一度だけ実行 |
| `run_onchange_` | 中身変更時に再実行 |

### 5.2 `.chezmoi.toml.tmpl` で対話的に取得する変数

```toml
[data]
    name = "<対話入力>"
    email = "<対話入力>"
    github_user = "<対話入力>"
    is_work_machine = false
```

これを `dot_gitconfig.tmpl` 等で差し込む。

### 5.3 `.chezmoiignore`

```
README.md
.github/
.git/
*.swp
.DS_Store
{{ if ne .chezmoi.os "darwin" }}
Brewfile
{{ end }}
```

### 5.4 共通 / マシン固有の分離

`~/.zshrc` の末尾で:

```zsh
# 共通設定 (chezmoi 管理)
# ... starship init、sheldon source、atuin init 等

# マシン固有設定 (chezmoi 非管理、.chezmoiignore に記載)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

secrets や仕事固有の環境変数は `~/.zshrc.local` に逃がす。`~/.zshrc.local` は `chezmoi add` しない (=source に取り込まない) ので、chezmoi はそもそも存在を知らない。`.chezmoiignore` に書く必要はない。

### 5.5 chezmoi 非管理にするもの

以下は明示的に `chezmoi add` しない:

- `~/.bashrc` (zsh メインなので放棄)
- `~/.config/fish/` (fish 使わない方針)
- `~/.config/zed/` (本 spec の対象外)
- `~/.config/github-copilot/`, `~/.config/gh/` の認証情報部分 (oauth token を含む)
- `~/.zshrc.local` (machine-local 用)
- `~/.ssh/known_hosts`, `~/.ssh/id_*` (鍵情報)

## 6. 既存環境からの移行 (段階的)

新規 Mac の一発復元とは別に、**今動いている Mac** で既存環境を壊さず chezmoi 化する手順。

| Phase | 内容 | git commit |
|-------|------|-----------|
| 0 | dotfiles リポ準備: `~/ghq/github.com/<user>/dotfiles` 作成、GitHub にリモート空リポ作成 | initial |
| 1 | `brew install chezmoi` → `chezmoi init` (既存 `~/` は無傷) | (この時点ではまだ空) |
| 2 | 既存設定を取り込む: `chezmoi add ~/.zshrc`, `~/.zprofile`, `~/.config/git/`, `~/.config/mise/` を順次 | phase 2: import existing dotfiles |
| 3 | 新規ツール導入: starship, sheldon, atuin, zoxide, ripgrep, fd, lazygit, delta, eza, bat を `brew install` し、各設定ファイルを chezmoi 配下に新規作成。`~/.zshrc` を sheldon/atuin/starship を読むように書き換え | phase 3: add modern CLI tools |
| 4 | LazyVim 化: `mv ~/.config/nvim ~/.config/nvim.bak` → `git clone LazyVim/starter` → `.git` 削除 → カスタム lua 追加 → `chezmoi add ~/.config/nvim/` | phase 4: switch to LazyVim |
| 5 | bootstrap script & Brewfile 作成: `run_once_before_install-packages.sh.tmpl`、Brewfile、CI、justfile を整備 | phase 5: bootstrap automation |

各 Phase で commit を切り、途中で止まっても巻き戻し可能。

## 7. 新規 Mac での bootstrap フロー

```
新 Mac (Xcode CLT 済み、macOS のみ)
   │
   │ 1. chezmoi 本体導入
   ▼
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <github-user>
   │
   │ 2. .chezmoi.toml.tmpl が対話 (name, email, github_user, is_work_machine)
   ▼
~/.local/share/chezmoi/ に dotfiles が clone される
   │
   │ 3. ファイル配置: dot_zshrc 等を ~ に展開
   ▼
   │ 4. run_once_before_install-packages.sh.tmpl 実行
   │    ├─ Homebrew 未導入なら install
   │    ├─ brew bundle (Brewfile から)
   │    ├─ mise install
   │    └─ atuin 初期化
   ▼
ユーザは Warp を開き `nvim` で LazyVim 初回起動
   │
   │ lazy.nvim が全プラグイン自動 install
   │ mason が LSP / formatter 自動 install
   ▼
完成
```

### 7.1 `run_once_before_install-packages.sh.tmpl` の内容

```bash
#!/bin/bash
set -euo pipefail

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# Brewfile から bundle install
brew bundle --file={{ .chezmoi.sourceDir }}/Brewfile

# mise でランタイム install (mise 設定がある場合のみ)
if command -v mise >/dev/null 2>&1 && [ -f "$HOME/.config/mise/config.toml" ]; then
  mise install
fi

# atuin のデータディレクトリは初回 zsh 起動時に作られる
# (`atuin init zsh` は .zshrc から sheldon 経由で source される)

echo "✅ bootstrap done. Open Warp and run 'nvim' to finish LazyVim setup."
```

### 7.2 `Brewfile` の内容

```ruby
# 新規ツール
brew "starship"
brew "sheldon"
brew "atuin"
brew "zoxide"
brew "ripgrep"
brew "fd"
brew "lazygit"
brew "git-delta"
brew "eza"
brew "bat"
brew "chezmoi"

# 既存ツール (宣言で再現性確保)
brew "neovim"
brew "mise"
brew "fzf"
brew "gh"

# GUI
cask "warp"
cask "zed"
```

## 8. 検証

### 8.1 ローカル検証 (`justfile`)

```just
# 編集後の差分確認
diff:
    chezmoi diff

# 適用 (chezmoi 自身が変更前に diff を表示する設計なのでそれに任せる)
apply:
    chezmoi apply --interactive

# 静的チェック
lint:
    shellcheck $(find . -name '*.sh' -o -name 'run_once_*' -type f)
    zsh -n dot_zshrc
    stylua --check dot_config/nvim/lua

# Docker bootstrap シミュレーション (Linux のみ、Brewfile は .chezmoiignore で除外済み)
test-bootstrap:
    docker run --rm -v $(pwd):/dotfiles ubuntu:22.04 bash -c '\
        apt-get update && apt-get install -y curl git zsh && \
        sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source=/dotfiles'
```

### 8.2 Neovim 検証

- `:checkhealth lazy` / `:checkhealth mason` / `:checkhealth treesitter`
- `:Lazy log` でプラグイン更新確認
- `nvim --startuptime /tmp/nvim-startup.log +q` で起動時間 (目標 < 150ms)

### 8.3 GitHub Actions CI

`.github/workflows/ci.yml`:

```yaml
name: dotfiles CI
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: shellcheck
        run: find . -name '*.sh' -o -name 'run_once_*' | xargs shellcheck
      - name: zsh syntax
        run: |
          sudo apt-get install -y zsh
          zsh -n dot_zshrc

  apply-dry-run:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          path: dotfiles
      - name: install chezmoi
        run: brew install chezmoi
      - name: dry-run
        run: |
          chezmoi init --source=$PWD/dotfiles
          chezmoi diff
          chezmoi apply --dry-run --verbose
```

### 8.4 受け入れチェックリスト (新規 Mac で手動確認)

- [ ] Warp を開いて zsh 起動、starship prompt 表示
- [ ] `nvim` 起動、LazyVim ロゴ表示
- [ ] `nvim ~/.zshrc` で telescope (`<leader>ff`, `<leader>fg`) が動作
- [ ] LSP 動作確認 (Go ファイルで `gd`、`K`)
- [ ] `lazygit` がスタンドアロンで開く
- [ ] `z <dirname>` で zoxide がジャンプ
- [ ] zsh プロンプトで ↑ キーで atuin history が表示
- [ ] `git log` が delta で色付け表示
- [ ] `eza --git` で git status カラー付き ls
- [ ] `mise` で既定のランタイムが動作

## 9. 設計上の決定事項と非採用案

| 検討項目 | 決定 | 非採用案と理由 |
|---------|------|--------------|
| 管理レイヤー | 素の dotfiles | Nix (nix-darwin/home-manager) は学習コストと既存 Homebrew 環境との二重管理を避けるため不採用 |
| エディタ | LazyVim (主) + Zed (補助) | 素の Neovim 自作はメンテ負担、Helix は plugin 未成熟 |
| multiplexer | なし | tmux/zellij は Warp の split/tab と機能重複、UI 二重化を避ける |
| shell | zsh | fish は既存 `.zshrc` 6KB の資産流用不可、bash は機能不足 |
| prompt | starship | Warp 既定装飾は Mac 固有で他環境再現性なし |
| dotfiles ツール | chezmoi | stow はテンプレ/secrets 非対応、git bare repo は学習コスト低いが拡張性低い |

## 10. リスクと対応

| リスク | 対応 |
|--------|------|
| `~/.zshrc` 直接編集してしまい `chezmoi apply` で上書き | `chezmoi diff` の習慣化、`chezmoi re-add` で取り込み直し |
| secrets を誤って commit | `~/.zshrc.local` 逃がし戦略、`.chezmoiignore` で除外、必要なら `chezmoi add --encrypt` |
| LazyVim アップデートで自分のカスタムが壊れる | カスタムは `lua/plugins/*.lua` に分離、LazyVim 本体ファイルは触らない |
| Warp の独自挙動が CLI と衝突 | Subshell detection OFF、AI と atuin 履歴は併存、衝突したら個別 issue として記録 |
| 既存 `~/.config/nvim/init.vim` の `jj`→ESC が失われる | LazyVim 移行時に `lua/plugins/keymaps.lua` に明示的に再定義 |

## 11. 完了の定義 (Definition of Done)

- [ ] dotfiles リポが GitHub に存在する
- [ ] 既存 Mac で chezmoi apply が差分ゼロで通る
- [ ] CI (lint + apply-dry-run) が green
- [ ] 第8.4節の受け入れチェックリストが全て ✅
- [ ] README に bootstrap 1コマンドが書かれている
