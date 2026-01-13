#!/bin/bash
#
# build-initramfs.sh - Constrói o initramfs para Gentoo com LUKS detached header
#
# Uso: ./build-initramfs.sh [--kernel-dir /usr/src/linux]
#

set -euo pipefail

# =============================================================================
# CONFIGURAÇÃO
# =============================================================================

INITRAMFS_DIR="/usr/src/initramfs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="${KERNEL_DIR:-/usr/src/linux}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# =============================================================================
# FUNÇÕES
# =============================================================================

msg() { echo -e "${GREEN}>>>${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { err "$1"; exit 1; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "Este script deve ser executado como root"
    fi
}

check_dependencies() {
    msg "Verificando dependências..."
    
    local missing=()
    
    # Verifica binários estáticos
    [[ -x /bin/busybox ]] || missing+=("busybox (USE='static')")
    [[ -x /sbin/cryptsetup.static ]] || [[ -x /sbin/cryptsetup ]] || missing+=("cryptsetup (USE='static static-libs')")
    [[ -x /sbin/btrfs.static ]] || [[ -x /sbin/btrfs ]] || missing+=("btrfs-progs (USE='static static-libs')")
    
    # Verifica se busybox é estático
    if [[ -x /bin/busybox ]]; then
        if ldd /bin/busybox 2>/dev/null | grep -q "not a dynamic"; then
            : # OK, é estático
        elif file /bin/busybox | grep -q "statically linked"; then
            : # OK, é estático  
        else
            warn "busybox pode não ser estático - verifique com 'file /bin/busybox'"
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Dependências faltando:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Instale com:"
        echo "  USE='static static-libs' emerge sys-apps/busybox sys-fs/cryptsetup sys-fs/btrfs-progs"
        exit 1
    fi
    
    msg "Dependências OK"
}

create_structure() {
    msg "Criando estrutura de diretórios..."
    
    rm -rf "$INITRAMFS_DIR"
    mkdir -p "$INITRAMFS_DIR"/{bin,sbin,etc,dev,dev/disk/{by-label,by-uuid,by-partuuid},dev/mapper,lib,lib64,mnt,mnt/usb,newroot,proc,sys,run,tmp}
    
    chmod 0555 "$INITRAMFS_DIR"/{proc,sys}
    chmod 1777 "$INITRAMFS_DIR"/tmp
}

copy_binaries() {
    msg "Copiando binários..."
    
    # Busybox
    cp -a /bin/busybox "$INITRAMFS_DIR/bin/"
    
    # Cryptsetup (prefere versão estática)
    if [[ -x /sbin/cryptsetup.static ]]; then
        cp -a /sbin/cryptsetup.static "$INITRAMFS_DIR/sbin/cryptsetup"
    else
        cp -a /sbin/cryptsetup "$INITRAMFS_DIR/sbin/"
        warn "Usando cryptsetup dinâmico - pode precisar de bibliotecas"
    fi
    
    # Btrfs (prefere versão estática)
    if [[ -x /sbin/btrfs.static ]]; then
        cp -a /sbin/btrfs.static "$INITRAMFS_DIR/sbin/btrfs"
    else
        cp -a /sbin/btrfs "$INITRAMFS_DIR/sbin/"
        warn "Usando btrfs dinâmico - pode precisar de bibliotecas"
    fi
    
    # Blkid (se disponível estático)
    if [[ -x /sbin/blkid.static ]]; then
        cp -a /sbin/blkid.static "$INITRAMFS_DIR/sbin/blkid"
    elif [[ -x /sbin/blkid ]]; then
        cp -a /sbin/blkid "$INITRAMFS_DIR/sbin/"
    fi
}

create_symlinks() {
    msg "Criando links simbólicos do busybox..."
    
    local busybox_applets=(
        "bin/sh"
        "bin/mount"
        "bin/umount"
        "bin/mkdir"
        "bin/cat"
        "bin/echo"
        "bin/ls"
        "bin/sleep"
        "bin/printf"
        "bin/clear"
        "bin/readlink"
        "sbin/switch_root"
        "sbin/setsid"
        "sbin/mdev"
    )
    
    # cttyhack pode estar em lugares diferentes
    if /bin/busybox --list | grep -q "cttyhack"; then
        busybox_applets+=("sbin/cttyhack")
    fi
    
    for applet in "${busybox_applets[@]}"; do
        ln -sf /bin/busybox "$INITRAMFS_DIR/$applet"
    done
}

create_device_nodes() {
    msg "Criando device nodes..."
    
    # Dispositivos essenciais
    mknod -m 600 "$INITRAMFS_DIR/dev/console" c 5 1
    mknod -m 666 "$INITRAMFS_DIR/dev/null" c 1 3
    mknod -m 666 "$INITRAMFS_DIR/dev/zero" c 1 5
    mknod -m 666 "$INITRAMFS_DIR/dev/tty" c 5 0
    mknod -m 620 "$INITRAMFS_DIR/dev/tty0" c 4 0
    mknod -m 620 "$INITRAMFS_DIR/dev/tty1" c 4 1
    mknod -m 444 "$INITRAMFS_DIR/dev/urandom" c 1 9
    mknod -m 444 "$INITRAMFS_DIR/dev/random" c 1 8
    
    # Device mapper
    mknod -m 660 "$INITRAMFS_DIR/dev/mapper/control" c 10 236
    
    # NVMe (Lenovo LOQ)
    mknod -m 660 "$INITRAMFS_DIR/dev/nvme0" c 241 0 2>/dev/null || true
    mknod -m 660 "$INITRAMFS_DIR/dev/nvme0n1" b 259 0 2>/dev/null || true
    mknod -m 660 "$INITRAMFS_DIR/dev/nvme0n1p1" b 259 1 2>/dev/null || true
    mknod -m 660 "$INITRAMFS_DIR/dev/nvme0n1p2" b 259 2 2>/dev/null || true
    mknod -m 660 "$INITRAMFS_DIR/dev/nvme0n1p3" b 259 3 2>/dev/null || true
    
    # SATA fallback
    mknod -m 660 "$INITRAMFS_DIR/dev/sda" b 8 0 2>/dev/null || true
    mknod -m 660 "$INITRAMFS_DIR/dev/sda1" b 8 1 2>/dev/null || true
    mknod -m 660 "$INITRAMFS_DIR/dev/sda2" b 8 2 2>/dev/null || true
    mknod -m 660 "$INITRAMFS_DIR/dev/sda3" b 8 3 2>/dev/null || true
}

install_init() {
    msg "Instalando script init..."
    
    if [[ -f "$SCRIPT_DIR/init" ]]; then
        cp "$SCRIPT_DIR/init" "$INITRAMFS_DIR/init"
        chmod 755 "$INITRAMFS_DIR/init"
    else
        die "Script init não encontrado em $SCRIPT_DIR/init"
    fi
}

install_configs() {
    msg "Instalando arquivos de configuração..."
    
    # mdev.conf
    if [[ -f "$SCRIPT_DIR/src/mdev.conf" ]]; then
        cp "$SCRIPT_DIR/src/mdev.conf" "$INITRAMFS_DIR/etc/mdev.conf"
    fi
}

verify_initramfs() {
    msg "Verificando initramfs..."
    
    local errors=0
    
    # Verifica arquivos essenciais
    [[ -x "$INITRAMFS_DIR/init" ]] || { err "init não encontrado ou não executável"; ((errors++)); }
    [[ -x "$INITRAMFS_DIR/bin/busybox" ]] || { err "busybox não encontrado"; ((errors++)); }
    [[ -x "$INITRAMFS_DIR/sbin/cryptsetup" ]] || { err "cryptsetup não encontrado"; ((errors++)); }
    [[ -x "$INITRAMFS_DIR/sbin/btrfs" ]] || { err "btrfs não encontrado"; ((errors++)); }
    [[ -c "$INITRAMFS_DIR/dev/console" ]] || { err "dev/console não criado"; ((errors++)); }
    [[ -b "$INITRAMFS_DIR/dev/nvme0n1" ]] || warn "dev/nvme0n1 não criado (pode ser criado dinamicamente)"
    
    if [[ $errors -gt 0 ]]; then
        die "Verificação falhou com $errors erro(s)"
    fi
    
    msg "Verificação OK"
}

show_summary() {
    echo ""
    echo "========================================"
    echo "  Initramfs criado com sucesso!"
    echo "========================================"
    echo ""
    echo "Localização: $INITRAMFS_DIR"
    echo ""
    echo "Próximos passos:"
    echo ""
    echo "1. Edite $INITRAMFS_DIR/init e configure:"
    echo "   - CRYPT_DISK_PARTUUID com o PARTUUID do seu disco"
    echo "   - Verifique USB_LABEL (padrão: INTFS_KEY)"
    echo ""
    echo "2. Configure o kernel em $KERNEL_DIR:"
    echo "   General setup --->"
    echo "     [*] Initial RAM filesystem and RAM disk (initramfs/initrd) support"
    echo "     ($INITRAMFS_DIR) Initramfs source file(s)"
    echo ""
    echo "3. Compile o kernel:"
    echo "   cd $KERNEL_DIR && make -j\$(nproc)"
    echo ""
    echo "4. Prepare o USB com os segredos:"
    echo "   - Formate com label 'INTFS_KEY'"
    echo "   - Copie key.img e header.img para a raiz"
    echo ""
    echo "Tamanho estimado: $(du -sh "$INITRAMFS_DIR" | cut -f1)"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    check_root
    check_dependencies
    create_structure
    copy_binaries
    create_symlinks
    create_device_nodes
    install_init
    install_configs
    verify_initramfs
    show_summary
}

main "$@"
