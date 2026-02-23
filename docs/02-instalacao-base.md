# 02 - Instalação Base

## Download do Stage3

```bash
cd /mnt/gentoo

# Download stage3 hardened
# Verificar URL atual em: https://www.gentoo.org/downloads/
# No momento do commit, o stage3 mais atual é o que está abaixo
BASE="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc"
TXT="latest-stage3-amd64-hardened-openrc.txt"
wget $BASE/$TXT
TAR=`cat $TXT | grep hardened | cut -d " " -f1`
wget $BASE/$TAR

# Download dos arquivos stage3 hardened para verificação

wget $BASE/$TAR.{CONTENTS.gz,DIGESTS,asc,sha256}
```

## Verificação

```bash
# Importar chave do Gentoo Release
gpg --keyserver hkps://keys.gentoo.org --recv-keys 13EBBDBEDE7A12775DFDB1BABB572E0E2D182910

# Verificar assinatura
gpg --verify stage3-*.tar.xz.asc stage3-*.tar.xz
gpg --output ${TAR}.DIGESTS.verified --verify stage3-*.tar.xz.DIGESTS
gpg --output ${TAR}.sha256.verified --verify stage3-*.tar.xz.sha256

# Verificar hash
sha256sum --check ${TAR}.sha256.verified
```

## Extração

```bash
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
```

## Configuração do Portage

### make.conf

```bash
cat > /mnt/gentoo/etc/portage/make.conf << 'EOF'
# Gentoo Hardened - Lenovo LOQ (Configuração inicial)
# Gerado em: $(date)

# Compilador padrão (app/misc/resolve-march-native)
COMMON_FLAGS="-march=alderlake -mabm -mno-kl -mno-pconfig -mno-sgx -mno-widekl -mshstk --param=l1-cache-line-size=64 --param=l1-cache-size=32 --param=l2-cache-size=12288 -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# Compilador RUST (Listar CPUs: # rustc -C target-cpu=help)
RUSTFLAGS="-C target-cpu=x86_64 opt-level=3 debug-assertions=on lto"

# Paralelismo (ajustar conforme CPU)
MAKEOPTS="-j12 -l12"
EMERGE_DEFAULT_OPTS="--jobs=12 --load-average=12"
# Arquitetura
CHOST="x86_64-pc-linux-gnu"
ACCEPT_KEYWORDS="amd64"
ACCEPT_LICENSE="-* @FREE"

# USE flags globais (minimal)
USE="hardened pipewire X -wayland -systemd -pulseaudio "

# GPU - NVIDIA Optimus
VIDEO_CARDS="nvidia intel"

# Input
INPUT_DEVICES="libinput"

# Diretórios
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"

# Idioma
LC_MESSAGES=C.UTF-8
L10N="en pt-BR"

# Logging
PORTAGE_ELOG_CLASSES="info warn error log qa"
PORTAGE_ELOG_SYSTEM="echo save"

# Features
FEATURES="split-elog buildpkg parallel-fetch candy"

# Mirrors (ajustar para seu país com o comando mirrorselect)
GENTOO_MIRRORS="https://gentoo.c3sl.ufpr.br/ https://mirrors.kernel.org/gentoo/ http://distfiles.gentoo.org"
EOF
```

### repos.conf

```bash
mkdir -p /mnt/gentoo/etc/portage/repos.conf

cat > /mnt/gentoo/etc/portage/repos.conf/gentoo.conf << 'EOF'
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = rsync
sync-uri = rsync://rsync.gentoo.org/gentoo-portage
sync-webrsync-verify-signature = true
auto-sync = yes
sync-rsync-verify-jobs = 1
sync-rsync-verify-metamanifest = yes
sync-rsync-verify-max-age = 3
sync-openpgp-key-path = /usr/share/openpgp-keys/gentoo-release.asc
sync-openpgp-key-refresh-retry-count = 40
sync-openpgp-key-refresh-retry-overall-timeout = 1200
sync-openpgp-key-refresh-retry-delay-exp-base = 2
sync-openpgp-key-refresh-retry-delay-max = 60
sync-openpgp-key-refresh-retry-delay-mult = 4
EOF
```

## OPCIONAL: Criando swapfile

```bash
btrfs subvolume create @swap
chattr +C @swap
fallocate -l 16GiB @swap/swapfile
chmod 600 @swap/swapfile
mkswap -L SWAP @swap/swapfile
swapon @swap/swapfile
```

## Preparando Chroot

```bash
# DNS
cp -v -L /etc/resolv.conf /mnt/gentoo/etc/

# Montar sistemas de arquivos necessários
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run
```

## Entrando no Chroot

```bash
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"
```

## Configuração Inicial

```bash
# Sincronizar repositório
emerge-webrsync
emerge --sync

# Selecionar profile hardened
eselect profile list
eselect profile set default/linux/amd64/23.0/hardened

# Atualizar @world
emerge --ask --verbose --update --deep --newuse @world

# Gerar CPU_FLAGS_X86
emerge --ask --oneshot app-portage/cpuid2cpuflags

# Inpsecione primeiro, se está curioso
cpuid2cpuflags

# E, então, copie a saída para dentro do diretório package.use
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags
```

## INFO: Checando quais USEFLAGS estão configurados, tanto do make.conf como do profile

```bash
emerge --info | grep ^USE=
```

## INFO: Checando quais USEFLAGS estão configuradas apenas no profile

```bash
USE_ORDER="defaults:pkginternal:repo" emerge --info | grep USE=
```

## INFO: Visualizar as USE flags que podem ser encontradas no sistema

```bash
less /var/db/repos/gentoo/profiles/use.desc
```

## INFO: Instalando app-portage/gentoolkit e checando USEFLAGS habilitadas para um pacote específico

```bash
emerge --ask --oneshot app-portage/gentoolkit
equery u <package-name>
```

## OPCIONAL: Visualizar qual licença está sendo utilizada no sistema

```bash
portageq envvar ACCEPT_LICENSE

# NOTE: A variável LICENSE em um ebuild é apenas uma diretriz para desenvolvedores e usuários do Gentoo. Não se trata de uma declaração legal e não há garantia de que reflita a realidade. Recomenda-se não confiar exclusivamente na interpretação da licença de um pacote de software feita pelo desenvolvedor do ebuild, mas sim verificar o próprio pacote em detalhes, incluindo todos os arquivos instalados no sistema.
```

## OPCIONAL: Selecionar mirrors

```bash
emerge --ask --verbose --oneshot app-portage/mirrorselect
mirrorselect -i -o >> /etc/portage/make.conf
```

## OPCIONAL: Lendo novos itens após atualizações

```bash
# Comando list traz uma visão por cima dos novos itens
eselect news list

# Comando read os novos itens podem ser lidos
eselect news read

# Commando purge novos itens podem ser removidos, uma vez que eles já foram lidos e não serão mais lidos
eselect news purge
```

## OPCIONAL: Configurando os pacotes gentoolkit, dialog, netselect, mirrorselect e cpuid2cpuflags no @world

```bash
# O comando impedirá que estes pacotes sejam excluídos utilizando o comando: emerge --depclean
emerge --noreplace app-portage/mirrorselect app-portage/cpuid2cpuflags app-portage/gentoolkit net-analyzer/netselect dev-util/dialog
```

## OPCIONAL: Atualizando o @world set

```bash
# Usuários que estejam executando uma instalação mais lenta podem solicitar que o Portage realize atualizações para alterações de pacotes, perfis e/ou flags USE no momento:
emerge --ask --verbose --update --deep --changed-use @world
```

## Timezone e Locale

```bash
# Timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# NTP
emerge --ask --oneshot net-misc/ntp
rc-service ntpd start
rc-update add ntpd default
# OU
date -s "AAAA-MM-DD HH:MM:SS"
hwclock --systohc --utc # OU: --localtime

# Locale
cat > /etc/locale.gen << 'EOF'
en_US.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
EOF

locale-gen
eselect locale list
eselect locale set en_US.UTF8

# Atualizar ambiente
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
```

## Ferramentas Essenciais

```bash
cat > /etc/portage/package.use/static << 'EOF'
sys-fs/cryptsetup static static-libs -udev
sys-fs/btrfs-progs static static-libs
sys-apps/busybox static -pam
>=sys-apps/util-linux-2.41.3 static-libs
>=dev-libs/json-c-0.18 static-libs
>=dev-libs/popt-1.19-r1 static-libs
>=app-crypt/argon2-20190702-r1 static-libs
>=dev-libs/openssl-3.5.5 static-libs
>=sys-fs/lvm2-2.03.22-r7 static static-libs -udev
>=virtual/libcrypt-2-r1 static-libs
>=sys-libs/libxcrypt-4.4.38 static-libs
>=dev-libs/lzo-2.10 static-libs
>=sys-fs/e2fsprogs-1.47.3-r1 static-libs
>=app-arch/zstd-1.5.7-r1 static-libs
>=virtual/zlib-1.3.1-r1 static-libs
>=sys-libs/zlib-1.3.1-r1 static-libs
EOF

# Instalar
emerge --ask sys-fs/cryptsetup sys-fs/btrfs-progs sys-apps/busybox

# Utilitários
emerge --ask app-editors/vim sys-apps/pciutils sys-apps/usbutils
emerge --noreplace app-editors/nano
```

## fstab

```bash
# Relembrando os comandos para obter UUIDs, caso não tenha feito anteriormente
GENTOO_ID=`blkid -s UUID -o value /dev/mapper/gentoo`
EFI_ID=`blkid -s UUID -o value /dev/sda1`

cat > /etc/fstab << "EOF"
# /etc/fstab - Gentoo Lenovo LOQ

# <fs>             <mountpoint>      <type>  <opts>                                                            <dump/pass>

# EFI (via /dev/sda1)
UUID=$EFI_ID       /boot/efi         vfat    rw,noatime,fmask=0077,dmask=0077                                  0 2

# Btrfs subvolumes (via /dev/mapper/gentoo)
UUID=$GENTOO_ID    /                 btrfs   rw,noatime,compress=zstd:1,ssd,space_cache=v2,subvol=@            0 0
UUID=$GENTOO_ID    /root             btrfs   rw,noatime,compress=zstd:1,ssd,space_cache=v2,subvol=@root        0 0
UUID=$GENTOO_ID    /home             btrfs   rw,noatime,compress=zstd:1,ssd,space_cache=v2,subvol=@home        0 0
UUID=$GENTOO_ID    /usr              btrfs   rw,noatime,compress=zstd:1,ssd,space_cache=v2,subvol=@usr         0 0
UUID=$GENTOO_ID    /var              btrfs   rw,noatime,compress=zstd:1,ssd,space_cache=v2,subvol=@var         0 0
UUID=$GENTOO_ID    /opt              btrfs   rw,noatime,compress=zstd:1,ssd,space_cache=v2,subvol=@opt         0 0

# Portage tmpfs (ajustar tamanho conforme RAM)
tmpfs              /var/tmp/portage  tmpfs   rw,nosuid,nodev,noatime,size=8G,mode=775,uid=portage,gid=portage  0 0
EOF

# Editar, conforme a sua necessidade, caso for necessário... 
vim /etc/fstab
```

## Hostname e Rede

```bash
# Hostname
echo "gentoo" > /etc/hostname

# Hosts
cat > /etc/hosts << 'EOF'
127.0.0.1   gentoo localhost
::1         gentoo localhost
EOF

# NetworkManager ou dhcpcd
# emerge --ask net-misc/dhcpcd
# ou
echo ">=net-wireless/wpa_supplicant-2.11-r4 dbus" > /etc/portage/package.use/networkmanager
emerge --ask net-misc/networkmanager
```

## Usuário

```bash
# Senha root
passwd

# Criar usuário
useradd -m -G wheel,audio,video,usb,portage -s /bin/bash [usuario]
passwd [usuario]

# doas
echo "app-admin/doas persist" >> /etc/portage/package.use/doas
emerge --ask app-admin/doas
echo "permit persist :wheel" >> /etc/doas.conf
```

## Checklist

- [ ] Stage3 baixado e verificado
- [ ] make.conf configurado
- [ ] repos.conf configurado
- [ ] Chroot funcionando
- [ ] Profile hardened selecionado
- [ ] @world atualizado
- [ ] Timezone e locale configurados
- [ ] Ferramentas para initramfs instaladas (estáticas)
- [ ] fstab configurado
- [ ] Hostname e rede
- [ ] Usuário criado
