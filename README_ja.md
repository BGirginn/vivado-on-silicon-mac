# Vivado on Silicon Mac — 日本語ガイド

[English README](README.md)

Apple Silicon Mac 上の x64 Docker コンテナで Vivado 2024.1 / 2025.1 を動作させるためのセットアップ・運用ガイドです。

---

## 目次

1. [前提条件](#1-前提条件)
2. [初回セットアップ](#2-初回セットアップ)
3. [コンテナの起動](#3-コンテナの起動)
4. [初回起動時の自動セットアップ](#4-初回起動時の自動セットアップ)
5. [TigerVNC Viewer の設定（HiDPI）](#5-tigervnc-viewer-の設定hidpi)
6. [Vivado CLI ワークフロー](#6-vivado-cli-ワークフロー)
7. [Claude Code の使い方](#7-claude-code-の使い方)
8. [トラブルシューティング](#8-トラブルシューティング)

---

## 1. 前提条件

### macOS 側

| 項目 | 要件 |
|------|------|
| Mac | Apple Silicon（M1/M2/M3/M4）、macOS 13 Ventura 以降推奨 |
| Docker Desktop | [docker.com](https://www.docker.com/products/docker-desktop/) からインストール |
| Rosetta 2 | `softwareupdate --install-rosetta` で導入（Docker x64 エミュレーション用） |
| TigerVNC Viewer | `brew install --cask tigervnc-viewer` |

### Vivado インストーラ

AMD/Xilinx の公式サイトから Vivado 2024.1 / 2025.1 の Linux 版インストーラを入手し、コンテナ内でインストールしてください（`scripts/install_vivado.sh` を参照）。

---

## 2. 初回セットアップ

### 2-1. リポジトリのクローン

```zsh
git clone <このリポジトリのURL>
cd vivado-on-silicon-mac
```

### 2-2. Digilent ボードファイルのサブモジュール初期化（任意）

Digilent の FPGA ボード（Arty、Nexys、Basys など）を使う場合:

```zsh
git submodule update --init
```

### 2-3. TigerVNC Viewer のインストール

```zsh
brew install --cask tigervnc-viewer
```

### 2-4. Docker イメージのビルド

```zsh
bash scripts/gen_image.sh
```

### 2-5. Claude Code の認証（任意）

コンテナ内で Claude Code を使うには、コンテナ初回起動後に以下を実行してください:

1. `scripts/attach.sh` でコンテナに接続
2. コンテナ内で `claude` を実行して認証フローを完了

```bash
claude
```
認証が完了すると、macOS 側の `~/.claude/` がコンテナ内の `/home/user/.claude/` にマウントされ、コンテナ内からも Claude Code を利用できるようになります。

---

## 3. コンテナの起動

```zsh
bash scripts/start_container.sh
```

起動後、TigerVNC Viewer が自動で開きます。接続ダイアログが表示されたらパスワードを入力してください（`scripts/vncpasswd` に記載）。

### 解像度について

- VNC 解像度: **3456×2160**（16インチ MBP Retina 2x スケール相当）
- DPI 設定: **192 dpi**（Retina 相当）
- TigerVNC Viewer を**全画面モード**で使用することを推奨します

---

## 4. 初回起動時の自動セットアップ

コンテナ初回起動時、`scripts/de_start.sh` が以下を自動実行します:

### `setup_tools.sh`（初回のみ）

- **Claude Code** — `~/.local/bin/claude` にインストール
- **eza** — アイコン付き `ls` 代替
- **bat** — シンタックスハイライト付き `cat` 代替
- **ripgrep** (`rg`) — 高速 `grep` 代替
- **fzf** — ファジーファインダー
- **zoxide** — スマート `cd` 代替
- **JetBrainsMono Nerd Font** — eza アイコン・ターミナル表示用
- **Inter フォント** — LXDE デスクトップ UI 用
- **WhiteSur GTK テーマ** — macOS 風ライトテーマ
- **WhiteSur アイコンテーマ** — macOS 風アイコン
- **WhiteSur カーソル** — macOS 風カーソル

### `setup_boards.sh`（毎回・冪等）

Digilent サブモジュールが存在する場合、ボードファイルを Vivado の `board_files` ディレクトリにシンボリックリンクで追加します。

---

## 5. TigerVNC Viewer の設定（HiDPI）

初回接続時に以下の設定を推奨します:

1. TigerVNC Viewer を開く
2. **Options → Display** タブ:
   - **Display mode**: `Full screen on current monitor`

VNC 接続先: `localhost:5901`

---

## 6. Vivado CLI ワークフロー

コンテナ内のターミナルは Vivado 環境が設定済みです（`container_bashrc` により自動 source）。

### よく使うコマンド

| 操作 | コマンド |
|------|---------|
| TCL インタラクティブシェル | `vivado -mode tcl` |
| TCL バッチ実行 | `vivado -mode batch -source build.tcl` |
| GUI を開く | `vivado-gui`（エイリアス） |
| プロジェクト GUI で開く | `vivado -nolog -nojournal myproject.xpr &` |
| 合成のみ | `vivado -mode batch -source synth.tcl -log synth.log` |
| ボード一覧確認 | `vivado -mode tcl` → `get_board_list` |

### 推奨プロジェクト構成

```
myproject/
  project.tcl      # create_project / open_project
  build.tcl        # synth + impl + bitstream のバッチ実行
  src/             # HDL ソース (.v, .sv, .vhd)
  constrs/         # XDC 制約ファイル
  ip/              # IP コア（生成出力は .gitignore で除外）
  Makefile         # make synth / make impl / make bit
```

### Makefile の例

```makefile
VIVADO = vivado -mode batch

synth:
	$(VIVADO) -source build.tcl -tclargs synth -log synth.log

impl:
	$(VIVADO) -source build.tcl -tclargs impl -log impl.log

bit:
	$(VIVADO) -source build.tcl -tclargs bitstream -log bit.log

.PHONY: synth impl bit
```

### bash エイリアス一覧

| エイリアス | 展開 |
|-----------|------|
| `ls` | `eza --icons` |
| `ll` | `eza --icons -lh` |
| `la` | `eza --icons -lah` |
| `lt` | `eza --icons --tree` |
| `cat` | `bat` |
| `grep` | `rg` |
| `vivado-gui` | `vivado -nolog -nojournal &` |
| `vivado-tcl` | `vivado -mode tcl` |
| `reload` | `source /home/user/scripts/container_bashrc` |

---

## 7. Claude Code の使い方

コンテナ内で Claude Code をそのまま使用できます。

### 起動方法

```bash
claude          # インタラクティブセッション
claude "質問"   # 単発の質問
claude --help   # ヘルプ
```

### コンテナ内での活用例

```bash
# HDL コードのレビュー
claude "このモジュールのタイミング制約を確認して"

# TCL スクリプトの生成
claude "Arty A7-35T 向けの create_project TCL スクリプトを書いて"

# エラーの解析
claude "Vivado のこのエラーを解説して: [ERROR] ..."
```

---

## 8. トラブルシューティング

### VNC が繋がらない

- Docker Desktop が起動しているか確認
- `docker ps` でコンテナが動いているか確認
- `scripts/start_container.sh` を再実行

### 解像度が低い / ぼやける

- TigerVNC Viewer を使っているか確認（macOS 標準の「画面共有」は HiDPI 非対応）
- VNC Viewer を全画面モードで使用
- `scripts/vnc_resolution` が `3456x2160` になっているか確認

### `eza`・`bat` などが見つからない

`~/.tools_setup_done` を削除して再実行:

```bash
rm ~/.tools_setup_done
bash /home/user/scripts/setup_tools.sh
```

### Digilent ボードが Vivado に表示されない

```bash
bash /home/user/scripts/setup_boards.sh
```

サブモジュールが未初期化の場合は macOS 側で:

```zsh
git submodule update --init
```

### Claude Code の認証エラー

コンテナ内で再認証:

```bash
claude
```

`~/.claude/` はコンテナにマウントされているため、コンテナを再起動しても認証情報は保持されます。

### プロンプトにアイコンが表示されない

TigerVNC Viewer の接続後、lxterminal のフォントが `JetBrainsMono Nerd Font Mono` になっているか確認してください（`setup_tools.sh` がインストール済みであれば自動設定されます）。

### `hw_server` のエラー

USB JTAG 転送は xvcd 経由で macOS 側のデバイスを使います。FPGA が未接続の場合、エラーは無視して構いません。
