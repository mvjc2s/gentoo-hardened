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
gpg --output stage3-*.tar.xz.DIGESTS.verified --verify stage3-*.tar.xz.DIGESTS
gpg --output stage3-*.tar.xz.sha256.verified --verify stage3-*.tar.xz.sha256

# Verificar hash
sha256sum --check stage3-*.tar.xz.sha256.verified

# Verificar 
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

# Compilador padrão
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# Compilador RUST (Listar CPUs: # rust -C target-cpu=help)
RUSTFLAGS="${RUSTFLAGS} -C target-cpu=native"

# Paralelismo (ajustar conforme CPU)
MAKEOPTS="-j$(nproc) -l$(nproc)"
EMERGE_DEFAULT_OPTS="--jobs=$(nproc) --load-average=$(nproc)"
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
GENTOO_MIRRORS="https://gentoo.c3sl.ufpr.br/ https://mirrors.kernel.org/gentoo/"
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

## OPCIONAL: Visualizar qual licença está sendo utilizada no sistema

```bash
portageq envvar ACCEPT_LICENSE

# NOTE: A variável LICENSE em um ebuild é apenas uma diretriz para desenvolvedores e usuários do Gentoo. Não se trata de uma declaração legal e não há garantia de que reflita a realidade. Recomenda-se não confiar exclusivamente na interpretação da licença de um pacote de software feita pelo desenvolvedor do ebuild, mas sim verificar o próprio pacote em detalhes, incluindo todos os arquivos instalados no sistema.
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
mkdir -p /etc/portage/package.use
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

# TIP: Após o comando acima, para fins de melhor organização do arquivo, mova a linha para a área adequada.
```

## INFO: Instalando app-portage/gentoolkit e checando USEFLAGS habilitadas para um pacote específico

```bash
emerge --ask --oneshot app-portage/gentoolkit
equery u <package-name
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

## OPCIONAL: Atualizando o @world set

```bash
# Usuários que estejam executando uma execução lenta podem solicitar que o Portage realize atualizações para alterações de pacotes, perfis e/ou flags USE no momento:
emerge --ask --verbose --update --deep --change-use @world
```

## Timezone e Locale

```bash
# Timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

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
# Cryptsetup estático para initramfs
echo "sys-fs/cryptsetup static static-libs" > /etc/portage/package.use/cryptsetup

# Btrfs estático para initramfs
echo "sys-fs/btrfs-progs static-libs" > /etc/portage/package.use/btrfs-progs

# Busybox estático
echo "sys-apps/busybox static" > /etc/portage/package.use/busybox

# Instalar
emerge --ask sys-fs/cryptsetup sys-fs/btrfs-progs sys-apps/busybox

# Utilitários
emerge --ask app-editors/vim sys-apps/pciutils sys-apps/usbutils
```

## fstab

```bash
# Obter UUIDs
#blkid

cat > /etc/fstab << 'EOF'
# /etc/fstab - Gentoo Lenovo LOQ

# <fs>             <mountpoint>      <type>  <opts>                                                            <dump/pass>

# EFI
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
emerge --ask net-misc/dhcpcd
# ou
# emerge --ask net-misc/networkmanager
```

## Usuário

```bash
# Senha root
passwd

# Criar usuário
useradd -m -G wheel,audio,video,usb,portage -s /bin/bash seu_usuario
passwd seu_usuario

# Sudo
emerge --ask app-admin/doas
echo "permit persist :wheel" >> /etc/sudoers
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
