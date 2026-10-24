#!/usr/bin/env bash
#
# install_recon_tools.sh
# Installs every tool used by the subdomain-recon script (ctfr, subfinder,
# findomain, assetfinder, gobuster, sublist3r, httpx-toolkit, nuclei, seclists)
# and copies/symlinks the resulting binaries + scripts into THIS script's
# own directory, so the recon script can call them locally if you want
# (e.g. ./ctfr.py, ./subfinder, etc.) in addition to them being on $PATH.
#
# Tested target: Debian/Ubuntu/Kali-style systems (apt-based).
# Run as root or with sudo rights (apt + go install need it for system dirs).

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Resolve this script's own directory — everything gets copied here
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[*] Installing tools, binaries will be collected in: $SCRIPT_DIR"

TOOLS_SRC_DIR="$SCRIPT_DIR/.recon_tools_src"   # scratch/build dir
mkdir -p "$TOOLS_SRC_DIR"

GOBIN_DIR="${GOBIN:-$HOME/go/bin}"
mkdir -p "$GOBIN_DIR"

need_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "sudo"
    else
        echo ""
    fi
}
SUDO="$(need_sudo)"

have() { command -v "$1" >/dev/null 2>&1; }

copy_bin() {
    # copy_bin <binary-name> — find it on PATH or in GOBIN and copy into SCRIPT_DIR
    local bin="$1"
    local src=""
    if have "$bin"; then
        src="$(command -v "$bin")"
    elif [ -x "$GOBIN_DIR/$bin" ]; then
        src="$GOBIN_DIR/$bin"
    fi
    if [ -n "$src" ]; then
        cp -f "$src" "$SCRIPT_DIR/$bin"
        chmod +x "$SCRIPT_DIR/$bin"
        echo "    -> copied $bin to $SCRIPT_DIR/$bin"
    else
        echo "    !! could not locate binary '$bin' to copy, check install step above"
    fi
}

# ---------------------------------------------------------------------------
# 1. Base system dependencies
# ---------------------------------------------------------------------------
echo "[*] Updating apt and installing base dependencies..."
$SUDO apt-get update -y
$SUDO apt-get install -y \
    git curl wget unzip build-essential \
    python3 python3-pip python3-venv \
    golang-go \
    ruby \
    jq \
    cargo

# Make sure Go env vars / PATH are usable in this script and future shells
export PATH="$PATH:$GOBIN_DIR:/usr/local/go/bin"
if ! grep -q 'go/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$PATH:$HOME/go/bin"' >> "$HOME/.bashrc"
fi

# ---------------------------------------------------------------------------
# 2. seclists (wordlists used by gobuster)
# ---------------------------------------------------------------------------
echo "[*] Installing seclists..."
if [ -d "/usr/share/seclists" ]; then
    echo "    -> seclists already present at /usr/share/seclists"
elif apt-cache show seclists >/dev/null 2>&1; then
    $SUDO apt-get install -y seclists
else
    $SUDO git clone --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists
fi

# ---------------------------------------------------------------------------
# 3. ctfr (crt.sh wildcard grabber) — plain python script
# ---------------------------------------------------------------------------
echo "[*] Installing ctfr..."
mkdir -p /root/BugHunting
if [ ! -d "/root/BugHunting/ctfr" ]; then
    $SUDO git clone https://github.com/UnaPibaGeek/ctfr.git /root/BugHunting/ctfr
fi
pip3 install --break-system-packages -r /root/BugHunting/ctfr/requirements.txt 2>/dev/null \
    || pip3 install --break-system-packages requests
cp -f /root/BugHunting/ctfr/ctfr.py "$SCRIPT_DIR/ctfr.py"
chmod +x "$SCRIPT_DIR/ctfr.py"
echo "    -> copied ctfr.py to $SCRIPT_DIR/ctfr.py"

# ---------------------------------------------------------------------------
# 4. subfinder (ProjectDiscovery)
# ---------------------------------------------------------------------------
echo "[*] Installing subfinder..."
if ! have subfinder; then
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
fi
copy_bin subfinder

# ---------------------------------------------------------------------------
# 5. findomain
# ---------------------------------------------------------------------------
echo "[*] Installing findomain..."
if ! have findomain; then
    if apt-cache show findomain >/dev/null 2>&1; then
        $SUDO apt-get install -y findomain
    else
        curl -sL https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip \
            -o "$TOOLS_SRC_DIR/findomain-linux.zip"
        unzip -o "$TOOLS_SRC_DIR/findomain-linux.zip" -d "$TOOLS_SRC_DIR"
        $SUDO install -m 755 "$TOOLS_SRC_DIR/findomain" /usr/local/bin/findomain
    fi
fi
copy_bin findomain

# ---------------------------------------------------------------------------
# 6. assetfinder (Tomnomnom)
# ---------------------------------------------------------------------------
echo "[*] Installing assetfinder..."
if ! have assetfinder; then
    go install -v github.com/tomnomnom/assetfinder@latest
fi
copy_bin assetfinder

# ---------------------------------------------------------------------------
# 7. gobuster
# ---------------------------------------------------------------------------
echo "[*] Installing gobuster..."
if ! have gobuster; then
    if apt-cache show gobuster >/dev/null 2>&1; then
        $SUDO apt-get install -y gobuster
    else
        go install -v github.com/OJ/gobuster/v3@latest
    fi
fi
copy_bin gobuster

# ---------------------------------------------------------------------------
# 8. sublist3r
# ---------------------------------------------------------------------------
echo "[*] Installing sublist3r..."
if ! have sublist3r; then
    if [ ! -d "$TOOLS_SRC_DIR/Sublist3r" ]; then
        git clone https://github.com/aboul3la/Sublist3r.git "$TOOLS_SRC_DIR/Sublist3r"
    fi
    pip3 install --break-system-packages -r "$TOOLS_SRC_DIR/Sublist3r/requirements.txt"
    $SUDO ln -sf "$TOOLS_SRC_DIR/Sublist3r/sublist3r.py" /usr/local/bin/sublist3r
    $SUDO chmod +x /usr/local/bin/sublist3r
fi
# copy the actual runnable script (wrapper + source) into script dir
cp -f "$TOOLS_SRC_DIR/Sublist3r/sublist3r.py" "$SCRIPT_DIR/sublist3r.py" 2>/dev/null || true
cat > "$SCRIPT_DIR/sublist3r" <<EOF
#!/usr/bin/env bash
exec python3 "$SCRIPT_DIR/sublist3r.py" "\$@"
EOF
chmod +x "$SCRIPT_DIR/sublist3r"
echo "    -> copied sublist3r.py and wrapper to $SCRIPT_DIR"

# ---------------------------------------------------------------------------
# 9. httpx-toolkit (ProjectDiscovery httpx, built/aliased as httpx-toolkit
#    to avoid clashing with the unrelated python httpx package some distros ship)
# ---------------------------------------------------------------------------
echo "[*] Installing httpx-toolkit..."
if ! have httpx-toolkit; then
    if apt-cache show httpx-toolkit >/dev/null 2>&1; then
        $SUDO apt-get install -y httpx-toolkit
    else
        go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
        # alias the compiled binary as httpx-toolkit so it matches the script
        if [ -x "$GOBIN_DIR/httpx" ]; then
            cp -f "$GOBIN_DIR/httpx" "$GOBIN_DIR/httpx-toolkit"
        fi
    fi
fi
copy_bin httpx-toolkit

# ---------------------------------------------------------------------------
# 10. nuclei (ProjectDiscovery)
# ---------------------------------------------------------------------------
echo "[*] Installing nuclei..."
if ! have nuclei; then
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
fi
copy_bin nuclei
# pull nuclei templates so the scan step actually has signatures to use
nuclei -update-templates >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "[+] Install complete. Tools copied into: $SCRIPT_DIR"
echo "[+] Contents:"
ls -la "$SCRIPT_DIR" | grep -vE '^\.$|^\.\.$'
echo
echo "NOTE: ctfr.py and sublist3r still need Python (requests, etc.) which was installed via pip3."
echo "If 'go install' binaries aren't found by 'have', open a new shell or 'source ~/.bashrc' first."
