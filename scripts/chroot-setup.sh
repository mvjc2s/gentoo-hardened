#!/bin/bash
#
# chroot-setup.sh - Prepara ambiente para chroot no Gentoo
#
# Uso: ./chroot-setup.sh [mount|umount|enter]
#

set -euo pipefail

ROOT="/mnt/gentoo"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

msg() { echo -e "${GREEN}>>>${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

check_root() {
    [[ $EUID -eq 0 ]] || err "Execute como root"
}

do_mount() {
    msg "Montando sistemas de arquivos para chroot..."
    
    [[ -d "$ROOT" ]] || err "$ROOT não existe"
    
    # Verificar se já está montado
    if mountpoint -q "$ROOT/proc"; then
        msg "Já montado"
        return 0
    fi
    
    # Montar
    mount --types proc /proc "$ROOT/proc"
    mount --rbind /sys "$ROOT/sys"
    mount --make-rslave "$ROOT/sys"
    mount --rbind /dev "$ROOT/dev"
    mount --make-rslave "$ROOT/dev"
    mount --bind /run "$ROOT/run"
    mount --make-slave "$ROOT/run"
    
    # DNS
    cp --dereference /etc/resolv.conf "$ROOT/etc/"
    
    msg "Montado com sucesso"
}

do_umount() {
    msg "Desmontando sistemas de arquivos..."
    
    # Ordem inversa
    umount -l "$ROOT/run" 2>/dev/null || true
    umount -l "$ROOT/dev" 2>/dev/null || true
    umount -l "$ROOT/sys" 2>/dev/null || true
    umount -l "$ROOT/proc" 2>/dev/null || true
    
    msg "Desmontado"
}

do_enter() {
    do_mount
    
    msg "Entrando no chroot..."
    chroot "$ROOT" /bin/bash -c 'source /etc/profile; export PS1="(chroot) $PS1"; exec /bin/bash'
}

show_usage() {
    echo "Uso: $0 [mount|umount|enter]"
    echo ""
    echo "Comandos:"
    echo "  mount   - Monta sistemas de arquivos necessários"
    echo "  umount  - Desmonta sistemas de arquivos"
    echo "  enter   - Monta (se necessário) e entra no chroot"
    echo ""
}

# Main
check_root

case "${1:-}" in
    mount)  do_mount ;;
    umount) do_umount ;;
    enter)  do_enter ;;
    *)      show_usage ;;
esac
