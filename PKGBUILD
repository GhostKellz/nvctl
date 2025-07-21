# Maintainer: Christopher Kelley <ckelley@ghostkellz.sh>
# Contributor: Christopher Kelley <ckelley@ghostkellz.sh>

pkgname=nvctl
pkgver=0.1.0
pkgrel=1
epoch=
pkgdesc="Pure Zig NVIDIA GPU control utility using ghostnv driver"
arch=('x86_64')
url="https://github.com/ghostkellz/nvctl"
license=('MIT')
groups=()
depends=('nvidia' 'nvidia-utils')
optdepends=(
    'nvidia-open: Open source NVIDIA kernel modules'
    'gamescope: Gaming compositor integration'
    'wayland: VRR support for Wayland compositors'
)
makedepends=('zig>=0.15.0' 'git')
checkdepends=()
provides=('nvctl')
conflicts=('nvcontrol')
replaces=('nvcontrol')
backup=()
options=()
install=nvctl.install
changelog=
source=("$pkgname::git+https://github.com/ghostkellz/nvctl.git#tag=v$pkgver"
        "ghostnv::git+https://github.com/ghostkellz/ghostnv.git"
        "phantom::git+https://github.com/ghostkellz/phantom.git"
        "flash::git+https://github.com/ghostkellz/flash.git")
noextract=()
sha256sums=('SKIP'
            'SKIP' 
            'SKIP'
            'SKIP')

prepare() {
    cd "$pkgname"
    
    # Initialize git submodules if they exist
    if [ -f .gitmodules ]; then
        git submodule update --init --recursive
    fi
}

build() {
    cd "$pkgname"
    
    # Set up Zig build environment
    export ZIG_SYSTEM_LINKER_HACK=1
    
    # Build the project
    zig build -Doptimize=ReleaseSafe -Dsystem-tray=false
}

check() {
    cd "$pkgname"
    
    # Run tests
    zig build test
}

package() {
    cd "$pkgname"
    
    # Install main binary
    install -Dm755 "zig-out/bin/$pkgname" "$pkgdir/usr/bin/$pkgname"
    
    # Install documentation
    install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
    install -Dm644 COMMANDS.md "$pkgdir/usr/share/doc/$pkgname/COMMANDS.md"
    install -Dm644 CHANGELOG.md "$pkgdir/usr/share/doc/$pkgname/CHANGELOG.md"
    
    # Install license
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    
    # Install shell completions (if they exist)
    if [ -d "completions" ]; then
        install -Dm644 completions/bash/$pkgname "$pkgdir/usr/share/bash-completion/completions/$pkgname"
        install -Dm644 completions/zsh/_$pkgname "$pkgdir/usr/share/zsh/site-functions/_$pkgname"
        install -Dm644 completions/fish/$pkgname.fish "$pkgdir/usr/share/fish/vendor_completions.d/$pkgname.fish"
    fi
    
    # Install desktop file (if GUI components are built)
    if [ -f "assets/$pkgname.desktop" ]; then
        install -Dm644 "assets/$pkgname.desktop" "$pkgdir/usr/share/applications/$pkgname.desktop"
    fi
    
    # Install icon (if available)
    if [ -f "assets/$pkgname.png" ]; then
        install -Dm644 "assets/$pkgname.png" "$pkgdir/usr/share/pixmaps/$pkgname.png"
    fi
    
    # Install systemd user service (if available)
    if [ -f "systemd/$pkgname.service" ]; then
        install -Dm644 "systemd/$pkgname.service" "$pkgdir/usr/lib/systemd/user/$pkgname.service"
    fi
    
    # Install udev rules for GPU access
    if [ -f "udev/99-$pkgname.rules" ]; then
        install -Dm644 "udev/99-$pkgname.rules" "$pkgdir/usr/lib/udev/rules.d/99-$pkgname.rules"
    fi
    
    # Create directories for runtime files
    install -dm755 "$pkgdir/var/lib/$pkgname"
    install -dm755 "$pkgdir/etc/$pkgname"
}

# vim:set ts=2 sw=2 et: