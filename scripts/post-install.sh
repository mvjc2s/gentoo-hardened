#!/bin/bash
#
# post-install.sh - Tarefas de pós-instalação do Gentoo
#
# Execute dentro do chroot após instalação base
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg() { echo -e "${GREEN}>>>${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# =============================================================================
# VERIFICAÇÕES
# =============================================================================

check_chroot() {
    if [[ "$(stat -c %d:%i /)" == "$(stat -c %d:%i /proc/1/root/.)" ]]; then
        err "Este script deve ser executado dentro do chroot"
        exit 1
    fi
}

# =============================================================================
# SERVIÇOS BÁSICOS
# =============================================================================

setup_services() {
    msg "Configurando serviços..."
    
    # syslog
    emerge --ask --noreplace app-admin/sysklogd
    rc-update add sysklogd default
    
    # cron
    emerge --ask --noreplace sys-process/cronie
    rc-update add cronie default
    
    # mlocate (find rápido)
    emerge --ask --noreplace sys-apps/mlocate
    
    # SSH (opcional)
    read -p "Instalar SSH server? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        emerge --ask --noreplace net-misc/openssh
        rc-update add sshd default
    fi
    
    # DHCP
    rc-update add dhcpcd default
}

# =============================================================================
# FERRAMENTAS DE DESENVOLVIMENTO
# =============================================================================

setup_dev_tools() {
    msg "Instalando ferramentas de desenvolvimento..."
    
    emerge --ask --noreplace \
        dev-vcs/git \
        app-editors/neovim \
        sys-apps/ripgrep \
        sys-apps/fd \
        app-shells/fzf \
        dev-util/ctags
}

# =============================================================================
# DOCKER
# =============================================================================

setup_docker() {
    msg "Configurando Docker..."
    
    # USE flags
    cat > /etc/portage/package.use/docker << 'EOF'
app-containers/docker btrfs overlay
app-containers/containerd btrfs
EOF
    
    # Instalar
    emerge --ask app-containers/docker app-containers/docker-compose
    
    # Serviço
    rc-update add docker default
    
    # Adicionar usuário ao grupo docker
    read -p "Usuário para grupo docker: " docker_user
    if id "$docker_user" &>/dev/null; then
        usermod -aG docker "$docker_user"
        msg "Usuário $docker_user adicionado ao grupo docker"
    else
        warn "Usuário $docker_user não encontrado"
    fi
}

# =============================================================================
# WAYLAND / SWAY (Opcional)
# =============================================================================

setup_wayland() {
    msg "Configurando Wayland/Sway..."
    
    # USE flags
    cat > /etc/portage/package.use/wayland << 'EOF'
gui-wm/sway swaybar swaybg swaylock swaymsg tray
gui-apps/foot themes
media-libs/mesa vulkan
EOF
    
    # Instalar
    emerge --ask \
        gui-wm/sway \
        gui-apps/foot \
        gui-apps/waybar \
        gui-apps/wofi \
        gui-apps/grim \
        gui-apps/slurp \
        gui-apps/wl-clipboard \
        x11-misc/xdg-utils
    
    # Seat management
    emerge --ask sys-auth/seatd
    rc-update add seatd default
    
    msg "Configure ~/.config/sway/config após o primeiro login"
}

# =============================================================================
# HARDENING ADICIONAL
# =============================================================================

setup_hardening() {
    msg "Aplicando hardening adicional..."
    
    # Kernel parameters
    cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
# Disable IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Enable SYN cookies
net.ipv4.tcp_syncookies = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log martians
net.ipv4.conf.all.log_martians = 1

# Randomize virtual address space
kernel.randomize_va_space = 2

# Restrict dmesg
kernel.dmesg_restrict = 1

# Restrict kernel pointers
kernel.kptr_restrict = 2

# Disable magic sysrq
kernel.sysrq = 0

# ASLR for mmap
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16
EOF
    
    # Permissões restritivas
    chmod 700 /boot
    chmod 700 /root
    chmod 600 /etc/shadow
    chmod 600 /etc/gshadow
    
    msg "Hardening aplicado"
}

# =============================================================================
# LIMPEZA
# =============================================================================

cleanup() {
    msg "Limpando..."
    
    # Remover distfiles antigos
    eclean-dist --deep
    
    # Remover pacotes órfãos
    emerge --ask --depclean
    
    # Rebuild dependências
    emerge --ask @preserved-rebuild
    
    # Atualizar ld cache
    ldconfig
    
    # Atualizar env
    env-update && source /etc/profile
}

# =============================================================================
# MENU
# =============================================================================

show_menu() {
    echo ""
    echo "========================================"
    echo "  Gentoo Post-Install Setup"
    echo "========================================"
    echo ""
    echo "1) Serviços básicos (syslog, cron, ssh)"
    echo "2) Ferramentas de desenvolvimento"
    echo "3) Docker"
    echo "4) Wayland/Sway"
    echo "5) Hardening adicional"
    echo "6) Limpeza"
    echo "7) Executar tudo"
    echo "0) Sair"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    check_chroot
    
    while true; do
        show_menu
        read -p "Opção: " choice
        
        case $choice in
            1) setup_services ;;
            2) setup_dev_tools ;;
            3) setup_docker ;;
            4) setup_wayland ;;
            5) setup_hardening ;;
            6) cleanup ;;
            7)
                setup_services
                setup_dev_tools
                setup_docker
                setup_wayland
                setup_hardening
                cleanup
                ;;
            0) exit 0 ;;
            *) warn "Opção inválida" ;;
        esac
    done
}

main "$@"
