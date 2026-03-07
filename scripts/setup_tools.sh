#!/bin/bash

# Idempotent first-run setup script.
# Installs CLI tools, fonts, and themes into the user home directory (no root required).
# Uses ~/.tools_setup_done as a marker to skip on subsequent runs.

MARKER="$HOME/.tools_setup_done"
if [ -f "$MARKER" ]; then
    echo "Tools already set up (remove $MARKER to re-run)."
    exit 0
fi

echo "=== Setting up tools and themes ==="

# ── Helpers ───────────────────────────────────────────────────────────────────
latest_tag() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | grep -o '"[^"]*"' | tail -1 | tr -d '"'
}

install_bin() {
    # Usage: install_bin <tmpdir> <binary-name>
    local dir="$1" name="$2"
    local bin
    bin=$(find "$dir" -type f -name "$name" | head -1)
    if [ -z "$bin" ]; then
        echo "WARNING: $name not found after extraction — skipping"
        return 1
    fi
    cp "$bin" "$HOME/.local/bin/$name"
    chmod +x "$HOME/.local/bin/$name"
}

# ── Directories ───────────────────────────────────────────────────────────────
mkdir -p "$HOME/.local/bin" "$HOME/.fonts" "$HOME/.themes" "$HOME/.icons"
mkdir -p "$HOME/.config/gtk-3.0"

# ── Claude Code ───────────────────────────────────────────────────────────────
echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash || true

# ── eza ───────────────────────────────────────────────────────────────────────
echo "Installing eza..."
EZA_VER=$(latest_tag "eza-community/eza")
mkdir -p /tmp/eza-dl
curl -fsSL "https://github.com/eza-community/eza/releases/download/${EZA_VER}/eza_x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /tmp/eza-dl 2>/dev/null || true
install_bin /tmp/eza-dl eza
rm -rf /tmp/eza-dl

# ── bat ───────────────────────────────────────────────────────────────────────
echo "Installing bat..."
BAT_VER=$(latest_tag "sharkdp/bat")
mkdir -p /tmp/bat-dl
curl -fsSL "https://github.com/sharkdp/bat/releases/download/${BAT_VER}/bat-${BAT_VER}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /tmp/bat-dl 2>/dev/null || true
install_bin /tmp/bat-dl bat
rm -rf /tmp/bat-dl

# ── ripgrep ───────────────────────────────────────────────────────────────────
echo "Installing ripgrep..."
RG_VER=$(latest_tag "BurntSushi/ripgrep")
mkdir -p /tmp/rg-dl
curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VER}/ripgrep-${RG_VER}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /tmp/rg-dl 2>/dev/null || true
install_bin /tmp/rg-dl rg
rm -rf /tmp/rg-dl

# ── fzf ───────────────────────────────────────────────────────────────────────
echo "Installing fzf..."
FZF_VER=$(latest_tag "junegunn/fzf")
mkdir -p /tmp/fzf-dl
curl -fsSL "https://github.com/junegunn/fzf/releases/download/${FZF_VER}/fzf-${FZF_VER#v}-linux_amd64.tar.gz" \
    | tar -xz -C /tmp/fzf-dl 2>/dev/null || true
install_bin /tmp/fzf-dl fzf
rm -rf /tmp/fzf-dl

# ── zoxide ────────────────────────────────────────────────────────────────────
echo "Installing zoxide..."
curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash || true

# ── JetBrainsMono Nerd Font ───────────────────────────────────────────────────
echo "Installing JetBrainsMono Nerd Font..."
NF_VER=$(latest_tag "ryanoasis/nerd-fonts")
mkdir -p /tmp/nf-dl
curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VER}/JetBrainsMono.tar.xz" \
    | tar -xJ -C /tmp/nf-dl 2>/dev/null || true
find /tmp/nf-dl -name '*.ttf' -o -name '*.otf' | xargs -I{} cp {} "$HOME/.fonts/" 2>/dev/null || true
rm -rf /tmp/nf-dl
fc-cache -f "$HOME/.fonts"

# ── Inter font ────────────────────────────────────────────────────────────────
echo "Installing Inter font..."
curl -fsSL "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip" -o /tmp/Inter.zip
unzip -q /tmp/Inter.zip -d /tmp/Inter 2>/dev/null || true
find /tmp/Inter -name "*.otf" -o -name "*.ttf" | xargs -I{} cp {} "$HOME/.fonts/" 2>/dev/null || true
rm -rf /tmp/Inter /tmp/Inter.zip
fc-cache -f "$HOME/.fonts"

# ── WhiteSur GTK theme ────────────────────────────────────────────────────────
echo "Installing WhiteSur GTK theme..."
curl -fsSL "https://github.com/vinceliuice/WhiteSur-gtk-theme/archive/refs/heads/master.tar.gz" \
    | tar -xz -C /tmp
bash /tmp/WhiteSur-gtk-theme-master/install.sh --dest "$HOME/.themes" --color Light 2>/dev/null || true
rm -rf /tmp/WhiteSur-gtk-theme-master

# ── WhiteSur icon theme ───────────────────────────────────────────────────────
echo "Installing WhiteSur icon theme..."
curl -fsSL "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz" \
    | tar -xz -C /tmp
bash /tmp/WhiteSur-icon-theme-master/install.sh --dest "$HOME/.icons" 2>/dev/null || true
rm -rf /tmp/WhiteSur-icon-theme-master

# ── WhiteSur cursors ──────────────────────────────────────────────────────────
echo "Installing WhiteSur cursors..."
curl -fsSL "https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/heads/master.tar.gz" \
    | tar -xz -C /tmp
cp -r /tmp/WhiteSur-cursors-master/dist/WhiteSur-cursors "$HOME/.icons/" 2>/dev/null || true
rm -rf /tmp/WhiteSur-cursors-master

# ── GTK2 theme config ─────────────────────────────────────────────────────────
cat > "$HOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name = "WhiteSur-Light"
gtk-icon-theme-name = "WhiteSur"
gtk-font-name = "Inter 13"
gtk-cursor-theme-name = "WhiteSur-cursors"
gtk-cursor-theme-size = 24
EOF

# ── GTK3 theme config ─────────────────────────────────────────────────────────
cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name = WhiteSur-Light
gtk-icon-theme-name = WhiteSur
gtk-font-name = Inter 13
gtk-cursor-theme-name = WhiteSur-cursors
gtk-cursor-theme-size = 24
EOF

echo "=== Setup complete ==="
touch "$MARKER"
