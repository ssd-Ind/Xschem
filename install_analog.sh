#!/bin/bash
# =============================================================================
# install_analog.sh
# Open-Source Analog EDA Stack Installer
#
# Installs: Xschem + Sky130 PDK + ngspice + Magic VLSI
# Target:   Ubuntu 22.04 / Debian-based systems
#
# Usage:
#   chmod +x install_analog.sh
#   ./install_analog.sh            # full install
#   ./install_analog.sh --help     # show options
# =============================================================================

set -e
set -o pipefail

# ── Configurable paths ────────────────────────────────────────────────────────
# No version pins — all tools track their latest stable release at install time
INSTALL_DIR="$HOME/eda"           # root directory for all clones
XSCHEM_SIMDIR="$HOME/.xschem/simulations"
XSCHEM_LIBDIR="$HOME/.xschem/xschem_library"
FOUNDRY_DIR="$INSTALL_DIR/foundry"

# Sky130 submodule libraries to init (comment out ones you don't need)
SKY130_LIBS=(
    "libraries/sky130_fd_io/latest"
    "libraries/sky130_fd_pr/latest"
    "libraries/sky130_fd_sc_hd/latest"
    "libraries/sky130_fd_sc_hvl/latest"
    "libraries/sky130_fd_sc_hdll/latest"
    "libraries/sky130_fd_sc_hs/latest"
    "libraries/sky130_fd_sc_ms/latest"
    "libraries/sky130_fd_sc_ls/latest"
    "libraries/sky130_fd_sc_lp/latest"
)

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
banner()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}  $*${RESET}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; }

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-deps      Skip apt dependency installation"
    echo "  --skip-xschem    Skip Xschem build"
    echo "  --skip-pdk       Skip Sky130 PDK clone"
    echo "  --skip-ngspice   Skip ngspice build"
    echo "  --skip-magic     Skip Magic VLSI build"
    echo "  --help           Show this help"
    echo ""
    echo "Install root: $INSTALL_DIR"
}

# ── Parse args ─────────────────────────────────────────────────────────────────
SKIP_DEPS=0; SKIP_XSCHEM=0; SKIP_PDK=0; SKIP_NGSPICE=0; SKIP_MAGIC=0

for arg in "$@"; do
    case $arg in
        --skip-deps)    SKIP_DEPS=1 ;;
        --skip-xschem)  SKIP_XSCHEM=1 ;;
        --skip-pdk)     SKIP_PDK=1 ;;
        --skip-ngspice) SKIP_NGSPICE=1 ;;
        --skip-magic)   SKIP_MAGIC=1 ;;
        --help)         usage; exit 0 ;;
        *) warn "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

# ── Idempotent git clone ───────────────────────────────────────────────────────
# Usage: safe_clone <url> <dest_dir>
safe_clone() {
    local url="$1"
    local dest="$2"
    if [ -d "$dest/.git" ]; then
        info "Already cloned: $dest — pulling latest"
        git -C "$dest" pull --ff-only || warn "Pull failed (skipping, using existing clone)"
    else
        info "Cloning $url → $dest"
        git clone "$url" "$dest"
    fi
}

# ── 1. System dependencies ─────────────────────────────────────────────────────
install_deps() {
    banner "Step 1 — System Dependencies"
    sudo apt-get update -y

    # Core packages — available on all supported Ubuntu/Debian versions
    sudo apt-get install -y \
        git curl wget \
        libx11-dev libxrender1 libxrender-dev \
        libxcb1 libx11-xcb-dev \
        libcairo2 libcairo2-dev \
        flex bison \
        libxpm4 libxpm-dev \
        libxaw7-dev \
        libreadline-dev \
        gawk mawk automake libtool autoconf \
        build-essential gperf \
        libxml2-dev \
        libxml-libxml-perl libgd-perl \
        xterm \
        m4 \
        libgl1-mesa-dev libglu1-mesa-dev \
        --no-install-recommends

    # TCL/TK — versioned packages exist on 22.04/24.04; unversioned on 25.04+
    install_if_available tcl8.6 tcl8.6-dev tk8.6 tk8.6-dev \
        || sudo apt-get install -y tcl tcl-dev tk tk-dev

    # vim-gtk3 — may be vim-gtk3 or just vim on minimal installs
    install_if_available vim-gtk3 || sudo apt-get install -y vim

    # blt — Tk extension; may not exist on 25.04 repos
    install_if_available blt || warn "blt not available — skipping (non-critical)"

    # freeglut: split into libglut-dev on newer Ubuntu (25.04+)
    install_if_available freeglut3 freeglut3-dev \
        || sudo apt-get install -y libglut-dev \
        || warn "freeglut not found — Magic 3D features may be limited"

    success "System dependencies installed"
}

# Install packages only if they exist in the apt cache; return 1 if any are missing
install_if_available() {
    local missing=()
    for pkg in "$@"; do
        apt-cache show "$pkg" &>/dev/null || missing+=("$pkg")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Packages not found in apt cache: ${missing[*]}"
        return 1
    fi
    sudo apt-get install -y "$@"
}

# ── 2. Xschem ─────────────────────────────────────────────────────────────────
install_xschem() {
    banner "Step 2 — Xschem Schematic Editor"
    mkdir -p "$INSTALL_DIR"
    safe_clone "https://github.com/StefanSchippers/xschem.git" "$INSTALL_DIR/xschem"

    cd "$INSTALL_DIR/xschem"
    ./configure --prefix=/usr/local
    make -j"$(nproc)"
    sudo make install

    # Create ~/.xschem directory structure
    mkdir -p "$XSCHEM_SIMDIR"
    mkdir -p "$XSCHEM_LIBDIR"

    success "Xschem installed → $(which xschem)"
    cd "$HOME"
}

# ── 3. Sky130 PDK + xschem_sky130 symbols ─────────────────────────────────────
install_pdk() {
    banner "Step 3 — Sky130 PDK + Symbol Library"
    mkdir -p "$FOUNDRY_DIR"

    # xschem_sky130 symbols
    safe_clone "https://github.com/StefanSchippers/xschem_sky130.git" \
               "$XSCHEM_LIBDIR/xschem_sky130"

    # skywater-pdk spice models
    safe_clone "https://github.com/google/skywater-pdk" \
               "$FOUNDRY_DIR/skywater-pdk"

    cd "$FOUNDRY_DIR/skywater-pdk"

    info "Initialising Sky130 submodule libraries..."
    for lib in "${SKY130_LIBS[@]}"; do
        git submodule init "$lib"
    done
    git submodule update --jobs "$(nproc)"

    # Patch sky130_fd_pr for ngspice nf parameter ordering
    local pr_src="$FOUNDRY_DIR/skywater-pdk/libraries/sky130_fd_pr/latest"
    local pr_ng="$FOUNDRY_DIR/skywater-pdk/libraries/sky130_fd_pr_ngspice/latest"
    local patch_file="$XSCHEM_LIBDIR/xschem_sky130/sky130_fd_pr.patch"

    if [ ! -d "$FOUNDRY_DIR/skywater-pdk/libraries/sky130_fd_pr_ngspice" ]; then
        info "Creating patched sky130_fd_pr_ngspice..."
        cp -a "$FOUNDRY_DIR/skywater-pdk/libraries/sky130_fd_pr" \
              "$FOUNDRY_DIR/skywater-pdk/libraries/sky130_fd_pr_ngspice"
        cd "$pr_ng"
        patch -p2 < "$patch_file"
    else
        info "sky130_fd_pr_ngspice already exists — skipping patch"
    fi

    # Copy .spiceinit (from this repo's copy if present, else write a default)
    local spiceinit_dst="$XSCHEM_SIMDIR/.spiceinit"
    if [ -f "$(dirname "$0")/.spiceinit" ]; then
        cp "$(dirname "$0")/.spiceinit" "$spiceinit_dst"
        info "Copied .spiceinit from repo"
    elif [ ! -f "$spiceinit_dst" ]; then
        info "Writing default .spiceinit"
        cat > "$spiceinit_dst" << 'EOF'
* Speed up ngspice startup for Sky130
set ngbehavior=hsa
set skywaterpdk
EOF
    fi

    # Copy xschemrc into xschem_sky130 directory
    local xschemrc_src="$(dirname "$0")/xschemrc"
    if [ -f "$xschemrc_src" ]; then
        cp "$xschemrc_src" "$XSCHEM_LIBDIR/xschem_sky130/xschemrc"
        info "Copied xschemrc from repo"
    fi

    success "Sky130 PDK and symbols ready"
    cd "$HOME"
}

# ── 4. ngspice ────────────────────────────────────────────────────────────────
install_ngspice() {
    banner "Step 4 — ngspice Simulator (latest stable)"
    safe_clone "https://git.code.sf.net/p/ngspice/ngspice" "$INSTALL_DIR/ngspice"

    cd "$INSTALL_DIR/ngspice"
    git fetch --tags

    # Auto-resolve the highest ngspice-NN tag (e.g. ngspice-44)
    local latest_tag
    latest_tag=$(git tag --list 'ngspice-[0-9]*' | sort -t- -k2 -n | tail -1)
    [ -z "$latest_tag" ] && error "Could not resolve any ngspice-NN tag from the repo"
    info "Using latest ngspice tag: $latest_tag"
    git checkout "$latest_tag"

    ./autogen.sh

    # Build in a clean release subdirectory
    mkdir -p release
    cd release

    ../configure \
        --prefix=/usr/local \
        --with-x \
        --enable-xspice \
        --disable-debug \
        --enable-cider \
        --with-readline=yes \
        --enable-openmp

    make -j"$(nproc)"
    sudo make install

    success "ngspice installed → $(which ngspice)"
    cd "$HOME"
}

# ── 5. Magic VLSI ─────────────────────────────────────────────────────────────
install_magic() {
    banner "Step 5 — Magic VLSI Layout Tool"
    safe_clone "https://github.com/RTimothyEdwards/magic" "$INSTALL_DIR/magic"

    cd "$INSTALL_DIR/magic"

    # GCC 14+ (Ubuntu 25.04+) changed empty-parameter-list declarations from
    # warnings to hard errors. Magic's legacy C headers use this pattern heavily.
    # -std=gnu17 + Wno-error flags suppress the errors without breaking the build.
    local gcc_ver
    gcc_ver=$(gcc -dumpversion | cut -d. -f1)
    if [ "$gcc_ver" -ge 14 ]; then
        info "GCC $gcc_ver detected — applying legacy C compatibility flags for Magic"
        export CFLAGS="-g -std=gnu17 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types"
    fi

    ./configure --prefix=/usr/local
    make -j"$(nproc)"
    sudo make install
    unset CFLAGS

    success "Magic installed → $(which magic)"
    cd "$HOME"
}


# ── 6. Launch wrapper ──────────────────────────────────────────────────────────
install_launcher() {
    banner "Step 6 — Install xschem-sky130 launcher"

    cat > /tmp/xschem-sky130 << EOF
#!/bin/bash
# Launch xschem from the correct Sky130 working directory so xschemrc is found
XSCHEM_SKY130="$HOME/.xschem/xschem_library/xschem_sky130"
if [ ! -d "\$XSCHEM_SKY130" ]; then
    echo "ERROR: \$XSCHEM_SKY130 not found. Run install_analog.sh first."
    exit 1
fi
echo "Launching xschem from \$XSCHEM_SKY130"
cd "\$XSCHEM_SKY130" && exec xschem "\$@"
EOF

    chmod +x /tmp/xschem-sky130
    sudo mv /tmp/xschem-sky130 /usr/local/bin/xschem-sky130
    success "Launcher installed → type 'xschem-sky130' from anywhere to launch"
}

# ── Final summary ──────────────────────────────────────────────────────────────
print_summary() {
    banner "Installation Complete"
    echo ""
    echo -e "  ${BOLD}Tool versions:${RESET}"
    command -v xschem  &>/dev/null && echo -e "  ${GREEN}✔${RESET}  xschem  : $(xschem --version 2>&1 | head -1)"
    command -v ngspice &>/dev/null && echo -e "  ${GREEN}✔${RESET}  ngspice : $(ngspice --version 2>&1 | head -1)"
    command -v magic   &>/dev/null && echo -e "  ${GREEN}✔${RESET}  magic   : $(magic --version 2>&1 | head -1)"
    echo ""
    echo -e "  ${BOLD}Directories:${RESET}"
    echo -e "  EDA root   : $INSTALL_DIR"
    echo -e "  Xschem cfg : $HOME/.xschem"
    echo -e "  PDK        : $FOUNDRY_DIR/skywater-pdk"
    echo -e "  Symbols    : $XSCHEM_LIBDIR/xschem_sky130"
    echo ""
    echo -e "  ${BOLD}To launch:${RESET}"
    echo -e "  xschem-sky130          (from anywhere)"
    echo ""
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║   Analog EDA Stack Installer             ║"
    echo "  ║   xschem + sky130 + ngspice + magic      ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"
    info "Install root : $INSTALL_DIR"
    info "All tools    : latest stable at clone time"
    echo ""

    [ "$SKIP_DEPS"    -eq 0 ] && install_deps
    [ "$SKIP_XSCHEM"  -eq 0 ] && install_xschem
    [ "$SKIP_PDK"     -eq 0 ] && install_pdk
    [ "$SKIP_NGSPICE" -eq 0 ] && install_ngspice
    [ "$SKIP_MAGIC"   -eq 0 ] && install_magic
    install_launcher

    print_summary
}

main
