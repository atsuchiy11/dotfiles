# Warp + LazyVim TUI 開発環境 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** chezmoi 管理の dotfiles リポジトリを作り、Warp.app の中で動く zsh + starship + LazyVim + 主要 CLI ツール群を「新 Mac で 1 コマンド復元」できる状態にする。

**Architecture:** chezmoi の source dir (`~/.local/share/chezmoi/`) を git リポジトリ本体とし、`dot_*` 規約で `~/` 配下に展開する。既存の zsh/git/mise 設定を取り込み、新規ツール (starship/sheldon/atuin/zoxide/eza/bat/delta/lazygit/ripgrep/fd) と LazyVim を追加。`run_once_` script + Brewfile で新 Mac の bootstrap を自動化する。

**Tech Stack:** chezmoi, Homebrew, zsh, starship, sheldon, atuin, zoxide, Neovim/LazyVim (Lua), just, GitHub Actions.

**Reference:** `docs/superpowers/specs/2026-06-06-warp-lazyvim-tui-env-design.md`

**Note on execution style:** このプランは home directory を変更するため、各タスクは必ず実機で対話的に実行する。`chezmoi diff` を各タスクの検証ステップとして使う。シェル変更系は **新しい Warp タブを開いて確認** することが事実上の "テスト" になる。

---

## ファイル構造マップ

chezmoi source dir (`~/.local/share/chezmoi/`) の最終的な姿:

```
~/.local/share/chezmoi/
├── .chezmoiroot                              # 空ファイル (root マーカー)
├── .chezmoiignore                            # 取り込み除外
├── .chezmoi.toml.tmpl                        # 初回 init 時の対話テンプレ
├── README.md                                 # bootstrap 1コマンド記載
├── Brewfile                                  # brew bundle 用
├── justfile                                  # diff/apply/lint/test-bootstrap
├── .github/workflows/ci.yml                  # CI
├── docs/superpowers/{specs,plans}/           # 本 spec/plan をここに移動
├── dot_zshrc                                 # 既存取込 + 新規ツール hook 追記
├── dot_zprofile                              # 既存取込
├── dot_zshenv                                # 新規 (PATH 等の最小設定)
├── dot_config/
│   ├── starship.toml                         # 新規
│   ├── sheldon/plugins.toml                  # 新規
│   ├── atuin/config.toml                     # 新規
│   ├── git/{config,ignore}                   # 既存取込 + delta 設定追記
│   ├── mise/config.toml                      # 既存取込
│   ├── lazygit/config.yml                    # 新規
│   └── nvim/                                 # LazyVim starter + 自前カスタム
│       ├── init.lua
│       ├── lazy-lock.json
│       ├── stylua.toml
│       ├── .neoconf.json
│       ├── lua/config/{autocmds,keymaps,lazy,options}.lua
│       └── lua/plugins/{colorscheme,lsp,keymaps}.lua   # ← カスタム
├── private_dot_ssh/config.tmpl               # ~/.ssh/config (perm 600)
└── run_once_before_install-packages.sh.tmpl  # bootstrap script
```

非管理 (chezmoi add しないもの): `~/.zshrc.local`, `~/.bashrc`, `~/.config/fish/`, `~/.config/zed/`, `~/.config/gh/*` の認証情報, `~/.ssh/known_hosts`, `~/.ssh/id_*`。

---

## Phase A: リポジトリと chezmoi の準備

### Task 1: GitHub 上に空の dotfiles リポを作る

**手動ステップ (ブラウザで実施):**
1. https://github.com/new を開く
2. Repository name: `dotfiles`
3. Visibility: **Public** を推奨 (chezmoi の `init` がそのまま走るため)。secrets は別管理する設計
4. "Initialize this repository with a README" は **OFF** (こちらから push するため)
5. Create repository

**Files:** なし (リモート作業のみ)

- [ ] **Step 1: 空リポを作成し URL を控える**

期待: `https://github.com/<GITHUB_USER>/dotfiles.git` が `git ls-remote` で 200 を返す

```bash
# GITHUB_USER を実値に置き換えて確認
GITHUB_USER=<your-github-handle>
git ls-remote https://github.com/$GITHUB_USER/dotfiles.git 2>&1 | head -3
```

期待出力: 空 (commit がまだないため) or `warning: You appear to have cloned an empty repository`

- [ ] **Step 2: GitHub username をメモ**

以降のタスクで `<GITHUB_USER>` プレースホルダを実値で置き換える。

---

### Task 2: chezmoi をインストール

**Files:** なし (グローバルインストール)

- [ ] **Step 1: chezmoi の有無確認**

Run: `which chezmoi`
Expected: 何も出力されない (まだ無い)

- [ ] **Step 2: brew で install**

```bash
brew install chezmoi
```

- [ ] **Step 3: バージョン確認**

Run: `chezmoi --version`
Expected: `chezmoi version 2.x.x` 等が表示される

---

### Task 3: chezmoi init で source dir を作る

**Files:**
- Create: `~/.local/share/chezmoi/` (chezmoi が作る)

- [ ] **Step 1: chezmoi init 実行**

```bash
chezmoi init
```

source dir が空の状態で作られる。既存 `~/` の中身は **一切変更されない**。

- [ ] **Step 2: source dir 確認**

Run: `ls -la ~/.local/share/chezmoi/`
Expected: `.git/` ディレクトリのみ (chezmoi が自動で git init している)

- [ ] **Step 3: リモート設定**

```bash
chezmoi cd
git remote add origin https://github.com/<GITHUB_USER>/dotfiles.git
git branch -M main
exit
```

`chezmoi cd` は source dir に cd した subshell を開く。`exit` で抜ける。

- [ ] **Step 4: リモート確認**

```bash
chezmoi git -- remote -v
```

Expected: `origin  https://github.com/<GITHUB_USER>/dotfiles.git (fetch)` 等が表示される

---

### Task 4: spec/plan ドキュメントを chezmoi 配下に移動

現在 `~/dotfiles-spec/` にある spec と plan を chezmoi の source 配下に移し、`~/dotfiles-spec/` は廃止する。

**Files:**
- Move: `~/dotfiles-spec/docs/superpowers/specs/2026-06-06-warp-lazyvim-tui-env-design.md` → `~/.local/share/chezmoi/docs/superpowers/specs/`
- Move: `~/dotfiles-spec/docs/superpowers/plans/2026-06-06-warp-lazyvim-tui-env.md` → `~/.local/share/chezmoi/docs/superpowers/plans/`
- Delete: `~/dotfiles-spec/`

- [ ] **Step 1: docs を移動**

```bash
mkdir -p ~/.local/share/chezmoi/docs/superpowers/{specs,plans}
mv ~/dotfiles-spec/docs/superpowers/specs/*.md ~/.local/share/chezmoi/docs/superpowers/specs/
mv ~/dotfiles-spec/docs/superpowers/plans/*.md ~/.local/share/chezmoi/docs/superpowers/plans/
```

- [ ] **Step 2: 旧ディレクトリを削除**

```bash
rm -rf ~/dotfiles-spec
```

- [ ] **Step 3: 移動後の確認**

Run: `ls ~/.local/share/chezmoi/docs/superpowers/specs/ ~/.local/share/chezmoi/docs/superpowers/plans/`
Expected: 各ディレクトリに `.md` ファイルが1つずつ

- [ ] **Step 4: 必要なら git の identity を初期化**

```bash
chezmoi git -- config user.name >/dev/null 2>&1 && \
  chezmoi git -- config user.email >/dev/null 2>&1 && \
  echo "git identity OK" || echo "MISSING: set git config user.name/user.email globally"
```

Expected: `git identity OK`。MISSING の場合は以下:

```bash
git config --global user.name "tsuchiyaatsushishi"
git config --global user.email "atsuchiy11@gmail.com"
```

- [ ] **Step 5: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "docs: add design and implementation plan for Warp+LazyVim TUI env"
chezmoi git -- push -u origin main
```

Expected: `main` ブランチが GitHub に push される

---

### Task 5: `.chezmoiroot` と最小 README を作る

**Files:**
- Create: `~/.local/share/chezmoi/.chezmoiroot`
- Create: `~/.local/share/chezmoi/README.md`

- [ ] **Step 1: `.chezmoiroot` を作成**

`.chezmoiroot` はファイルの存在自体がマーカー、中身は空でよい。

```bash
touch ~/.local/share/chezmoi/.chezmoiroot
```

- [ ] **Step 2: README.md を作成**

Write to `~/.local/share/chezmoi/README.md`:

```markdown
# dotfiles

Personal dotfiles for macOS (Apple Silicon), managed with chezmoi.

## Bootstrap on a new Mac

Prerequisite: Xcode Command Line Tools (`xcode-select --install`).

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <GITHUB_USER>
```

This will:
1. Install chezmoi
2. Clone this repo into `~/.local/share/chezmoi/`
3. Prompt for `name`, `email`, `github_user`, `is_work_machine`
4. Run `run_once_before_install-packages.sh` (Homebrew + Brewfile + mise install)
5. Apply all `dot_*` files to `~/`

Then open Warp and run `nvim` once — LazyVim will install plugins on first launch.

## Components

See `docs/superpowers/specs/2026-06-06-warp-lazyvim-tui-env-design.md`.
```

(`<GITHUB_USER>` は実際の値に置き換える)

- [ ] **Step 3: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "chore: add chezmoiroot marker and README"
chezmoi git -- push
```

---

### Task 6: `.chezmoi.toml.tmpl` で対話プロンプトを定義

**Files:**
- Create: `~/.local/share/chezmoi/.chezmoi.toml.tmpl`

- [ ] **Step 1: テンプレを書く**

Write to `~/.local/share/chezmoi/.chezmoi.toml.tmpl`:

```toml
{{- $name := promptStringOnce . "name" "Your full name" -}}
{{- $email := promptStringOnce . "email" "Your email" -}}
{{- $githubUser := promptStringOnce . "github_user" "Your GitHub username" -}}
{{- $isWork := promptBoolOnce . "is_work_machine" "Is this a work machine?" false -}}

[data]
    name = {{ $name | quote }}
    email = {{ $email | quote }}
    github_user = {{ $githubUser | quote }}
    is_work_machine = {{ $isWork }}
```

`promptStringOnce` / `promptBoolOnce` は **値が既に config にあれば再質問しない**。

- [ ] **Step 2: 自分の環境用に config を生成**

```bash
chezmoi init
```

Expected: 上記4項目を対話的に聞かれる
- name → `tsuchiyaatsushishi` (または好みの表示名)
- email → `atsuchiy11@gmail.com`
- github_user → 実際の GitHub username
- is this a work machine? → `n` (個人用)

- [ ] **Step 3: 生成された config を確認**

Run: `cat ~/.config/chezmoi/chezmoi.toml`

Expected: 上で入力した4項目が `[data]` セクションに記録されている

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: add chezmoi.toml.tmpl with interactive prompts"
chezmoi git -- push
```

---

## Phase B: 既存設定の取り込み

### Task 7: 既存 dotfiles のセキュリティ事前チェック

取り込む前に **secrets が含まれていないか** 確認する。

**Files:** 読み取りのみ

- [ ] **Step 1: zshrc/zprofile の secrets 検索**

```bash
grep -nE "(API_KEY|TOKEN|SECRET|PASSWORD|sk-|ghp_|github_pat_)" ~/.zshrc ~/.zprofile 2>/dev/null
```

Expected: 何もマッチしない、または機密でないコメントのみ

- [ ] **Step 2: マッチが出た場合の対応**

機密情報があれば該当行を `~/.zshrc.local` (非管理ファイル) に手で移動:

```bash
# 例: 該当行をコピーして
echo 'export GITHUB_TOKEN=...' >> ~/.zshrc.local
chmod 600 ~/.zshrc.local
# 元の ~/.zshrc から該当行を削除 (手で編集)
```

- [ ] **Step 3: git config の確認**

```bash
grep -nE "(token|password|secret)" ~/.config/git/config 2>/dev/null
```

Expected: 空、もしくは無害 (signingkey 等は OK)

- [ ] **Step 4: 確認完了**

このタスクは確認のみなので commit なし。問題がなければ次へ。

---

### Task 8: 既存 zshrc / zprofile を取り込む

**Files:**
- Modify: `~/.local/share/chezmoi/dot_zshrc` (chezmoi が作る)
- Modify: `~/.local/share/chezmoi/dot_zprofile` (chezmoi が作る)

- [ ] **Step 1: zshrc を chezmoi 配下に取り込む**

```bash
chezmoi add ~/.zshrc
```

Expected: `~/.local/share/chezmoi/dot_zshrc` が作られる (元の `~/.zshrc` はそのまま)

- [ ] **Step 2: zprofile を取り込む**

```bash
chezmoi add ~/.zprofile
```

- [ ] **Step 3: 取り込み内容を確認**

```bash
chezmoi managed
```

Expected: `.zshrc` と `.zprofile` がリストされる

- [ ] **Step 4: 差分ゼロの確認**

```bash
chezmoi diff
```

Expected: 出力なし (source と destination が一致)

- [ ] **Step 5: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: import existing zsh config"
chezmoi git -- push
```

---

### Task 9: 既存 git / mise config を取り込む

**Files:**
- Modify: `~/.local/share/chezmoi/dot_config/git/` (chezmoi が作る)
- Modify: `~/.local/share/chezmoi/dot_config/mise/` (chezmoi が作る)

- [ ] **Step 1: git config を取り込む**

```bash
chezmoi add ~/.config/git/
```

Expected: `~/.local/share/chezmoi/dot_config/git/config` 等が作られる

- [ ] **Step 2: mise config を取り込む**

```bash
chezmoi add ~/.config/mise/
```

- [ ] **Step 3: 取り込んだ git config が name/email を含んでいないか確認**

```bash
cat ~/.local/share/chezmoi/dot_config/git/config | grep -E "name|email"
```

もし生の name/email が入っていたら、テンプレ化するため次の step へ。入っていなければ Step 5 へ。

- [ ] **Step 4: git config をテンプレ化 (必要なら)**

ファイル名を `config` → `config.tmpl` にリネームし、name/email 行を `{{ .name }}` / `{{ .email }}` に置換:

```bash
cd ~/.local/share/chezmoi/dot_config/git
mv config config.tmpl
```

`config.tmpl` の該当部分を以下のように編集:

```ini
[user]
    name = {{ .name }}
    email = {{ .email }}
```

その後 `chezmoi diff` で `~/.config/git/config` の中身が変わらないことを確認。

- [ ] **Step 5: 差分ゼロの確認**

```bash
chezmoi diff
```

Expected: 出力なし

- [ ] **Step 6: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: import git and mise configs"
chezmoi git -- push
```

---

### Task 10: `.chezmoiignore` を作成

**Files:**
- Create: `~/.local/share/chezmoi/.chezmoiignore`

- [ ] **Step 1: 内容を作成**

Write to `~/.local/share/chezmoi/.chezmoiignore`:

```
README.md
.github/
docs/

# OS / editor 雑多
*.swp
.DS_Store

# プラットフォーム別の除外
{{ if ne .chezmoi.os "darwin" }}
Brewfile
{{ end }}
```

`README.md`, `.github/`, `docs/` は git リポには置くが `~/` には展開しない。

- [ ] **Step 2: 適用テスト**

```bash
chezmoi diff
```

Expected: 出力なし (除外されたファイルは elsewhere に書き出されない)

- [ ] **Step 3: managed 確認**

```bash
chezmoi managed | grep -E "README|docs|.github"
```

Expected: 何も出力されない

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "chore: add chezmoiignore"
chezmoi git -- push
```

---

## Phase C: 新規 CLI ツール群の導入

### Task 11: 新規 brew パッケージをインストール

**Files:** なし (グローバルインストール)

- [ ] **Step 1: インストール**

```bash
brew install starship sheldon atuin zoxide ripgrep fd lazygit git-delta eza bat
```

- [ ] **Step 2: 個別確認**

```bash
for tool in starship sheldon atuin zoxide rg fd lazygit delta eza bat; do
  command -v $tool >/dev/null && echo "OK: $tool" || echo "MISSING: $tool"
done
```

Expected: 全て `OK: ...`

このタスクは commit 不要 (まだ chezmoi 配下に config を作っていない)。

---

### Task 12: starship 設定を作成

**Files:**
- Create: `~/.local/share/chezmoi/dot_config/starship.toml`

- [ ] **Step 1: ディレクトリ作成と config 配置**

```bash
mkdir -p ~/.local/share/chezmoi/dot_config
```

Write to `~/.local/share/chezmoi/dot_config/starship.toml`:

```toml
# starship: minimal but informative prompt
# https://starship.rs/config/

add_newline = true

format = """
$directory\
$git_branch\
$git_status\
$nodejs\
$golang\
$python\
$rust\
$cmd_duration\
$line_break\
$character"""

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"

[directory]
truncation_length = 3
truncate_to_repo = true
style = "bold cyan"

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "yellow"

[cmd_duration]
min_time = 2000
format = "took [$duration](bold yellow) "

[nodejs]
format = "via [⬢ $version](bold green) "

[golang]
format = "via [🐹 $version](bold cyan) "

[python]
format = "via [🐍 $version](bold yellow) "
```

- [ ] **Step 2: apply**

```bash
chezmoi apply
```

- [ ] **Step 3: 確認**

```bash
test -f ~/.config/starship.toml && echo OK || echo MISSING
```

Expected: `OK`

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: add starship config"
chezmoi git -- push
```

---

### Task 13: sheldon (zsh プラグイン管理) 設定

**Files:**
- Create: `~/.local/share/chezmoi/dot_config/sheldon/plugins.toml`

- [ ] **Step 1: plugins.toml を作成**

```bash
mkdir -p ~/.local/share/chezmoi/dot_config/sheldon
```

Write to `~/.local/share/chezmoi/dot_config/sheldon/plugins.toml`:

```toml
shell = "zsh"

[plugins]

[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"

[plugins.zsh-syntax-highlighting]
github = "zsh-users/zsh-syntax-highlighting"

[plugins.zsh-completions]
github = "zsh-users/zsh-completions"

[plugins.zsh-history-substring-search]
github = "zsh-users/zsh-history-substring-search"
```

- [ ] **Step 2: apply**

```bash
chezmoi apply
```

- [ ] **Step 3: sheldon でプラグインを取得**

```bash
sheldon lock
```

Expected: 各プラグインの clone ログ → 成功

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: add sheldon plugin config"
chezmoi git -- push
```

---

### Task 14: atuin 設定

**Files:**
- Create: `~/.local/share/chezmoi/dot_config/atuin/config.toml`

- [ ] **Step 1: config を作成**

```bash
mkdir -p ~/.local/share/chezmoi/dot_config/atuin
```

Write to `~/.local/share/chezmoi/dot_config/atuin/config.toml`:

```toml
# atuin: replace shell history with a searchable SQLite DB
# https://docs.atuin.sh/configuration/config/

# UI mode for the search interface
style = "compact"

# bind ↑ to atuin search
inline_height = 20

# Filter: by default search all history (not just current shell session)
filter_mode = "global"

# Auto-sync if logged in (not configured by default — local only)
auto_sync = false
update_check = false

# History search shows last-used-first
search_mode = "fuzzy"
```

- [ ] **Step 2: apply**

```bash
chezmoi apply
```

- [ ] **Step 3: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: add atuin config (local-only mode)"
chezmoi git -- push
```

---

### Task 15: ~/.zshrc に新規ツールの hook を追記

既存 `~/.zshrc` の末尾に starship/sheldon/atuin/zoxide の初期化を入れ、`~/.zshrc.local` source guard も追加する。

**Files:**
- Modify: `~/.local/share/chezmoi/dot_zshrc`

- [ ] **Step 1: 現在の zshrc 末尾を確認**

```bash
tail -10 ~/.local/share/chezmoi/dot_zshrc
```

末尾に何があるかメモする (既存設定の最終ブロックを壊さないため)。

- [ ] **Step 2: hooks を追記**

`chezmoi edit ~/.zshrc` で source ファイルを開き、**ファイル末尾** に以下を追記:

```zsh

# ========================================================================
# Managed by chezmoi: modern CLI tools wiring
# (Edit via `chezmoi edit ~/.zshrc`, not ~/.zshrc directly)
# ========================================================================

# sheldon: zsh plugin manager
if command -v sheldon >/dev/null 2>&1; then
  eval "$(sheldon source)"
fi

# starship: cross-shell prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# atuin: history replacement (binds ↑ and Ctrl+R)
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

# zoxide: smarter cd (z dirname)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# eza/bat aliases
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --git --icons'
  alias ll='eza -l --git --icons'
  alias la='eza -la --git --icons'
  alias tree='eza --tree --icons'
fi
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

# Machine-local overrides (chezmoi 非管理)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
```

`chezmoi edit` を終了すると自動で `chezmoi apply` 相当が走る。

- [ ] **Step 3: 差分確認**

```bash
chezmoi diff
```

Expected: `~/.zshrc` に上記ブロックが追加される差分のみ

- [ ] **Step 4: apply**

```bash
chezmoi apply
```

- [ ] **Step 5: zsh 構文チェック**

```bash
zsh -n ~/.zshrc
```

Expected: 何も出力されない (構文 OK)

- [ ] **Step 6: Warp の Subshell detection を OFF にする (手動 GUI 設定)**

starship を入れたので、Warp 標準のプロンプト装飾と二重表示にならないよう Warp 側を OFF にする:

1. Warp を開く → `Cmd + ,` で設定を開く
2. **Features** → **Session Navigation** → "Detect command output" を OFF
3. **Appearance** → "Show subshell decoration" の類があれば OFF

Warp のバージョンで項目名が変わる場合あり。要は「Warp がプロンプトを再描画/装飾しないようにする」設定を探して OFF。

- [ ] **Step 7: 新しい Warp タブで動作確認**

新しい Warp タブを開いて以下を確認:
- starship prompt が出る (➜ で終わるか緑/赤の文字、二重に Warp の装飾が出ていないこと)
- ↑ キーで atuin の search UI が出る
- `z` コマンドが存在する (`type z` で関数として定義されている)
- `ll` が eza になっている

- [ ] **Step 8: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: wire starship/sheldon/atuin/zoxide into zshrc"
chezmoi git -- push
```

---

### Task 16: git delta を有効化

**Files:**
- Modify: `~/.local/share/chezmoi/dot_config/git/config` (or `config.tmpl`)

- [ ] **Step 1: delta を git config に組み込む**

`chezmoi edit ~/.config/git/config` (テンプレ化していたら `.tmpl`) を開き、以下のセクションを追加:

```ini
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    light = false
    side-by-side = false
    line-numbers = true

[merge]
    conflictStyle = diff3

[diff]
    colorMoved = default
```

- [ ] **Step 2: apply**

```bash
chezmoi apply
```

- [ ] **Step 3: 動作確認**

任意の git リポで `git log -p` を実行し、出力が delta 風 (左に行番号、色付き) になっていることを確認。

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: enable git-delta for diff/log"
chezmoi git -- push
```

---

### Task 17: lazygit 設定

**Files:**
- Create: `~/.local/share/chezmoi/dot_config/lazygit/config.yml`

- [ ] **Step 1: 最小 config を作成**

```bash
mkdir -p ~/.local/share/chezmoi/dot_config/lazygit
```

Write to `~/.local/share/chezmoi/dot_config/lazygit/config.yml`:

```yaml
gui:
  showFileTree: true
  showRandomTip: false
  theme:
    lightTheme: false
    activeBorderColor:
      - green
      - bold
    inactiveBorderColor:
      - white
git:
  paging:
    colorArg: always
    pager: delta --paging=never --line-numbers --side-by-side=false
  overrideGpg: false
keybinding:
  universal:
    quit: q
```

- [ ] **Step 2: apply**

```bash
chezmoi apply
```

- [ ] **Step 3: 動作確認**

```bash
cd ~/.local/share/chezmoi
lazygit
```

期待: lazygit が立ち上がり、ファイルツリー表示、delta による diff pane。`q` で終了。

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: add lazygit config with delta pager"
chezmoi git -- push
```

---

## Phase D: LazyVim 導入

### Task 18: 既存 nvim 設定をバックアップ

**Files:**
- Move: `~/.config/nvim/init.vim` → `~/.config/nvim.bak/init.vim`

- [ ] **Step 1: バックアップ**

```bash
mv ~/.config/nvim ~/.config/nvim.bak
```

- [ ] **Step 2: 確認**

Run: `ls ~/.config/nvim.bak/`
Expected: `init.vim` が見える

このタスクは chezmoi 配下を触らないので commit なし。

---

### Task 19: LazyVim starter を導入

**Files:**
- Create: `~/.config/nvim/` (LazyVim starter から)

- [ ] **Step 1: starter を clone**

```bash
git clone https://github.com/LazyVim/starter ~/.config/nvim
```

- [ ] **Step 2: starter の .git を削除 (chezmoi 管理にするため)**

```bash
rm -rf ~/.config/nvim/.git
```

- [ ] **Step 3: 初回起動 (プラグイン install)**

```bash
nvim
```

期待: lazy.nvim の install UI が走る。完了したら `:q` で抜ける。

- [ ] **Step 4: ヘルスチェック**

```bash
nvim --headless +'checkhealth' +'qa' 2>&1 | head -40
```

明らかな ERROR がないこと。WARNING はある程度許容 (font icon 等)。

このタスクは chezmoi 配下を触らないので、まだ commit しない (Task 21 でまとめて取り込む)。

---

### Task 20: 自前カスタムプラグインを追加

**Files:**
- Create: `~/.config/nvim/lua/plugins/keymaps.lua`
- Create: `~/.config/nvim/lua/plugins/colorscheme.lua`
- Create: `~/.config/nvim/lua/plugins/lsp.lua`

- [ ] **Step 1: keymaps.lua を作成**

Write to `~/.config/nvim/lua/plugins/keymaps.lua`:

```lua
-- Custom key mappings on top of LazyVim defaults
return {
  -- LazyVim uses lua/config/keymaps.lua for direct keymap definitions,
  -- but we define them via a no-op plugin spec so they live in lua/plugins/.
  {
    "LazyVim/LazyVim",
    init = function()
      -- jj -> ESC (continuation of pre-LazyVim init.vim behavior)
      vim.keymap.set("i", "jj", "<ESC>", { silent = true, desc = "jj to escape" })
    end,
  },
}
```

- [ ] **Step 2: colorscheme.lua を作成**

Write to `~/.config/nvim/lua/plugins/colorscheme.lua`:

```lua
-- Default colorscheme: tokyonight (already shipped with LazyVim)
return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-storm",
    },
  },
}
```

- [ ] **Step 3: lsp.lua で gopls を有効化**

Write to `~/.config/nvim/lua/plugins/lsp.lua`:

```lua
-- LSP additions on top of LazyVim defaults
return {
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
  -- ensure mason installs the LSPs we want
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
```

- [ ] **Step 4: 起動して反映確認**

```bash
nvim
```

期待:
- 起動時に lazy.nvim が追加プラグインを install
- `:Mason` を開き gopls がインストール済みであることを確認
- 適当な `.go` ファイルを `nvim foo.go` で開き、LSP が動く
- `colorscheme` が tokyonight-storm

`:q` で抜ける。

- [ ] **Step 5: 起動時間チェック**

```bash
nvim --startuptime /tmp/nvim-startup.log +q && head -3 /tmp/nvim-startup.log
tail -1 /tmp/nvim-startup.log
```

期待: 末尾の total が 200ms 未満程度 (キャッシュ後)

---

### Task 21: ~/.config/nvim/ を chezmoi 配下に取り込む

**Files:**
- Modify: `~/.local/share/chezmoi/dot_config/nvim/` (chezmoi が作る)

- [ ] **Step 1: 取り込み**

```bash
chezmoi add ~/.config/nvim/
```

期待: `~/.local/share/chezmoi/dot_config/nvim/` に init.lua, lazy-lock.json, lua/, stylua.toml 等が複製される

- [ ] **Step 2: 差分ゼロの確認**

```bash
chezmoi diff
```

Expected: 出力なし

- [ ] **Step 3: 大量のプラグインデータが混入していないか確認**

```bash
ls ~/.local/share/chezmoi/dot_config/nvim/
```

Expected: `init.lua`, `lua/`, `lazy-lock.json`, `stylua.toml`, `.neoconf.json` 程度。プラグイン本体 (`~/.local/share/nvim/lazy/`) は chezmoi が触らないことを確認。

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: import LazyVim config with custom plugins"
chezmoi git -- push
```

---

## Phase E: bootstrap 自動化

### Task 22: Brewfile を作成

**Files:**
- Create: `~/.local/share/chezmoi/Brewfile`

- [ ] **Step 1: Brewfile を作成**

Write to `~/.local/share/chezmoi/Brewfile`:

```ruby
# Formulae - CLI tools
brew "chezmoi"
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
brew "neovim"
brew "mise"
brew "fzf"
brew "gh"
brew "just"

# Casks - GUI apps
cask "warp"
cask "zed"
```

- [ ] **Step 2: ローカルで bundle check (差分なしの確認)**

```bash
brew bundle check --file=~/.local/share/chezmoi/Brewfile
```

Expected: `The Brewfile's dependencies are satisfied.`

差分がある場合、`brew bundle --file=...` で追加 install する。

- [ ] **Step 3: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: add Brewfile for bootstrap"
chezmoi git -- push
```

---

### Task 23: run_once bootstrap script

**Files:**
- Create: `~/.local/share/chezmoi/run_once_before_install-packages.sh.tmpl`

- [ ] **Step 1: script を作成**

Write to `~/.local/share/chezmoi/run_once_before_install-packages.sh.tmpl`:

```bash
#!/bin/bash
set -euo pipefail

echo "▶ chezmoi bootstrap: starting…"

# ① Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "▶ Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Silicon の場合の brew パス
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ② Brewfile から bundle install
echo "▶ brew bundle…"
brew bundle --file={{ .chezmoi.sourceDir }}/Brewfile

# ③ mise でランタイム install (config がある場合のみ)
if command -v mise >/dev/null 2>&1 && [ -f "$HOME/.config/mise/config.toml" ]; then
  echo "▶ mise install…"
  mise install
fi

# ④ sheldon プラグインを事前ロック
if command -v sheldon >/dev/null 2>&1 && [ -f "$HOME/.config/sheldon/plugins.toml" ]; then
  echo "▶ sheldon lock…"
  sheldon lock
fi

echo "✅ bootstrap done."
echo "   Next: open Warp and run 'nvim' once to let LazyVim install plugins."
```

- [ ] **Step 2: 実行権限を確認**

chezmoi は `run_once_` プレフィックスのファイルを apply 時に自動実行するので chmod 不要だが、shellcheck をかける:

```bash
shellcheck ~/.local/share/chezmoi/run_once_before_install-packages.sh.tmpl 2>&1 | head -20
```

Expected: エラー無し、または template 表記 (`{{ ... }}`) に関する parse error のみ (shellcheck はテンプレを理解しないので template 行のエラーは無視 OK)

template 行を `# shellcheck disable=SC1083` 等で抑制するのは過剰、無視で OK。

- [ ] **Step 3: 適用テスト (空運用)**

このスクリプトは `run_once_` なので、初回 apply 時にだけ走る。既に手作業で全部入れているので、chezmoi state を見ると "実行済み" マークがついてしまう状況を確認:

```bash
chezmoi state get-bucket --bucket=scriptState 2>&1 | head -20
```

(現時点で run_once が登録されていなければ、次の `chezmoi apply` で実行される)

意図的にスキップしたい場合: 中身の echo だけ吐く形なので、副作用は brew bundle と mise install。それぞれ既に冪等なので走らせて問題ない。

```bash
chezmoi apply
```

Expected: bootstrap script が走り、brew bundle が「依存満たされている」状態を確認して終わる

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: add run_once bootstrap script"
chezmoi git -- push
```

---

### Task 24: justfile (検証コマンド集約)

**Files:**
- Create: `~/.local/share/chezmoi/justfile`

- [ ] **Step 1: justfile を作成**

Write to `~/.local/share/chezmoi/justfile`:

```just
# Default: list recipes
default:
    @just --list

# Show pending changes
diff:
    chezmoi diff

# Apply with interactive prompts
apply:
    chezmoi apply --interactive

# Static checks
lint:
    @echo "▶ shellcheck"
    -find . -type f \( -name '*.sh' -o -name 'run_once_*' \) -print0 \
        | xargs -0 shellcheck 2>&1 | head -50
    @echo "▶ zsh -n dot_zshrc"
    zsh -n dot_zshrc
    @echo "▶ stylua --check"
    -stylua --check dot_config/nvim/lua 2>&1 | head -30
    @echo "✅ lint done"

# Verify no drift between source and destination
verify:
    chezmoi verify

# Simulate bootstrap in a clean Linux container
test-bootstrap:
    docker run --rm -v $(pwd):/dotfiles ubuntu:22.04 bash -c "\
        apt-get update -qq && \
        apt-get install -y -qq curl git zsh ca-certificates && \
        sh -c '\$(curl -fsLS get.chezmoi.io)' -- init --apply --source=/dotfiles"

# Show what files chezmoi manages
managed:
    chezmoi managed

# Open the source dir
cd:
    chezmoi cd
```

- [ ] **Step 2: just でリスト確認**

```bash
cd ~/.local/share/chezmoi
just
```

Expected: 上記レシピが一覧表示される

- [ ] **Step 3: lint を実行**

```bash
just lint
```

Expected: shellcheck/zsh -n/stylua check が動く (エラー無し、または stylua 未 install なら警告のみ)

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "chore: add justfile for verification tasks"
chezmoi git -- push
```

---

### Task 25: GitHub Actions CI

**Files:**
- Create: `~/.local/share/chezmoi/.github/workflows/ci.yml`

- [ ] **Step 1: workflow を作成**

```bash
mkdir -p ~/.local/share/chezmoi/.github/workflows
```

Write to `~/.local/share/chezmoi/.github/workflows/ci.yml`:

```yaml
name: dotfiles CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install shellcheck
        run: sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck zsh

      - name: shellcheck
        run: |
          find . -type f \( -name '*.sh' -o -name 'run_once_*' \) -print0 \
            | xargs -0 -r shellcheck

      - name: zsh -n dot_zshrc
        run: zsh -n dot_zshrc

  apply-dry-run-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          path: dotfiles

      - name: Install chezmoi
        run: brew install chezmoi

      - name: chezmoi init from local source
        run: |
          # Provide all .chezmoi.toml.tmpl prompts non-interactively
          mkdir -p ~/.config/chezmoi
          cat > ~/.config/chezmoi/chezmoi.toml <<EOF
          [data]
              name = "CI"
              email = "ci@example.com"
              github_user = "ci-bot"
              is_work_machine = false
          EOF
          chezmoi init --source="$PWD/dotfiles"

      - name: chezmoi diff
        run: chezmoi diff

      - name: chezmoi apply dry-run
        run: chezmoi apply --dry-run --verbose
```

- [ ] **Step 2: push して CI を走らせる**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "ci: add lint and apply-dry-run workflow"
chezmoi git -- push
```

- [ ] **Step 3: CI 確認**

```bash
gh run watch
```

Expected: lint と apply-dry-run-macos 両方が green

失敗した場合、ログを確認して fix の commit を作る (このタスクの中で対応する)。

---

### Task 26: private_dot_ssh テンプレ (任意、SSH 設定があるなら)

**Files:**
- Create: `~/.local/share/chezmoi/private_dot_ssh/config.tmpl`

- [ ] **Step 1: 既存 ~/.ssh/config の確認**

```bash
test -f ~/.ssh/config && cat ~/.ssh/config | head -30 || echo "no ~/.ssh/config"
```

ファイルが無ければこのタスク全体を **スキップ** して Task 27 へ。あれば次へ。

- [ ] **Step 2: 取り込み**

```bash
chezmoi add ~/.ssh/config
```

期待: `~/.local/share/chezmoi/private_dot_ssh/config` ができる (`private_` で perm 600 が保証される)

- [ ] **Step 3: secrets 確認**

```bash
grep -nE "IdentityFile|Password" ~/.local/share/chezmoi/private_dot_ssh/config
```

Identity file パスが個別 Mac で変わるなら `.tmpl` 化:

```bash
cd ~/.local/share/chezmoi/private_dot_ssh
mv config config.tmpl
```

そして該当行を `{{ if .is_work_machine }}...{{ end }}` 等で分岐。今は不要なら未対応で OK。

- [ ] **Step 4: コミット**

```bash
chezmoi git -- add -A
chezmoi git -- commit -m "feat: import ssh config"
chezmoi git -- push
```

---

## Phase F: 受け入れと最終確認

### Task 27: 受け入れチェックリスト

**Files:** なし (検証のみ)

新しい Warp タブを開いて以下を一つずつ確認:

- [ ] **Step 1: shell prompt**

新タブを開く → starship prompt (`➜` または `✗`) が表示される。

- [ ] **Step 2: zsh プラグイン**

`ls` の途中で suggestion が表示される (zsh-autosuggestions)。コマンドの色付け (zsh-syntax-highlighting)。

- [ ] **Step 3: atuin**

`↑` を押すと atuin の search UI が起動。`Ctrl+R` も同様。

- [ ] **Step 4: zoxide**

```bash
z dotfiles 2>/dev/null || cd ~/.local/share/chezmoi
z chezmoi
```

`z` で chezmoi source dir にジャンプできる。

- [ ] **Step 5: eza / bat**

```bash
ls
cat justfile
```

`ls` が eza のアイコン付き出力、`cat` が bat のシンタックスハイライト。

- [ ] **Step 6: LazyVim**

```bash
nvim
```

- LazyVim ロゴ表示
- `<Space>ff` で telescope find_files
- `<Space>fg` で telescope live_grep
- `<Space>gg` で lazygit
- `:checkhealth lazy` でエラー無し
- `jj` で挿入モードから戻る

- [ ] **Step 7: git + delta**

任意の git リポで `git log -p` または `git diff` を実行 → delta の色付き表示。

- [ ] **Step 8: mise**

```bash
mise list
```

既存ランタイム (Go/Node 等) がリストされる。

- [ ] **Step 9: chezmoi の同期状態**

```bash
chezmoi verify
```

Expected: 差分なし、終了コード 0

- [ ] **Step 10: チェック結果を README に追記**

すべて ✅ になったら、README に「受け入れ確認済み (YYYY-MM-DD)」の行を追加してコミット:

```bash
chezmoi cd
# README.md の末尾に
cat >> README.md <<'EOF'

## Verification

Last verified on 2026-06-06 on macOS (Apple Silicon).
EOF
git add README.md
git commit -m "docs: mark verification complete"
git push
exit
```

---

### Task 28: 新規 Mac での bootstrap シミュレーション (任意、Docker)

新規 Mac での体験を Linux 上でドライランする。GUI アプリ (Warp/Zed) は当然入らないが、CLI 部分は同じパスを通る。

**Files:** なし

- [ ] **Step 1: just で test-bootstrap を実行**

```bash
cd ~/.local/share/chezmoi
just test-bootstrap
```

期待: Ubuntu コンテナで chezmoi が install → init → prompt 入力 (CI と同じく非対話化されていないので手動で入力) → apply。Brewfile は `.chezmoiignore` 内の `{{ if ne .chezmoi.os "darwin" }}Brewfile{{ end }}` で Linux ではスキップされる。

LazyVim が ripgrep/fd を要求するが、コンテナにはないので一部 warning が出る。これは Mac の正規 bootstrap では問題にならない (brew が入れる)。

- [ ] **Step 2: 結果を確認**

エラーなく終了すること。エラーが出た場合は run_once script や `.chezmoiignore` を修正してから再実行。

このタスクは Docker 利用環境がない場合スキップして問題ない。

---

## 完了の定義 (Definition of Done)

すべての Task が ✅ になり、以下が満たされた状態:

- GitHub リポ `https://github.com/<GITHUB_USER>/dotfiles` に main ブランチが存在
- 最新コミットの CI が green
- ローカルの `chezmoi verify` が差分ゼロ
- Task 27 の受け入れチェックリストが全て ✅
- README に bootstrap 1コマンドと検証日が記載

---

## 参考: タスク依存関係

```
Phase A (Repo/chezmoi setup)
   1 → 2 → 3 → 4 → 5 → 6
                     │
Phase B (Existing import)
                     ↓
                  7 → 8 → 9 → 10
                              │
Phase C (Modern CLI tools)    ↓
                  11 → 12 → 13 → 14 → 15 → 16 → 17
                                              │
Phase D (LazyVim)                             ↓
                  18 → 19 → 20 → 21
                              │
Phase E (Bootstrap)           ↓
                  22 → 23 → 24 → 25 → 26
                                   │
Phase F (Acceptance)               ↓
                  27 → 28
```

Phase A の最後 (Task 6) と Phase B の頭 (Task 7) の間は同期点。それ以降は Phase 単位で順序を守れば OK。
