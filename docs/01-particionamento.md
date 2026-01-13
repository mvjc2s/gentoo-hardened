# 01 - Particionamento e LUKS

## Visão Geral

Este setup usa:
- LUKS2 com detached header (header em USB externo)
- Keyfile separado também criptografado
- Sem header no disco principal = plausible deniability

## Particionamento do NVMe

```bash
# Identificar o dispositivo NVMe
NVME=/dev/nvme0n1

# Criar tabela de partições GPT
parted -a optimal $NVME mklabel gpt

# Partição EFI (512MB)
parted -a optimal $NVME mkpart primary fat32 1MiB 513MiB
parted $NVME set 1 esp on

# Partição para LUKS (resto do disco)
parted -a optimal $NVME mkpart primary 513MiB 100%

# Verificar
parted $NVME print
```

## Formatando EFI

```bash
mkfs.vfat -F32 -n "EFI" ${NVME}p1
```

## Preparando USB para Secrets

```bash
# Identificar USB
USB=/dev/sdX  # CUIDADO: verificar com lsblk

# Criar partição
parted -a optimal $USB mklabel gpt
parted -a optimal $USB mkpart primary fat32 1MiB 100%

# Formatar com label específica
mkfs.vfat -F32 -n "INTFS_KEY" ${USB}1

# Montar
mkdir -p /mnt/usb
mount ${USB}1 /mnt/usb
```

## Criando Keyfile Criptografado

O keyfile é um arquivo pequeno, ele mesmo criptografado com LUKS, que contém dados aleatórios usados como chave para o disco principal.

```bash
cd /mnt/usb

# Criar arquivo de 4MB com dados aleatórios
dd if=/dev/urandom of=key.img bs=1M count=4

# Criptografar o keyfile
cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --hash sha512 \
    --key-size 512 \
    --iter-time 5000 \
    --pbkdf argon2id \
    key.img

# Abrir o keyfile
cryptsetup luksOpen key.img lukskey

# Preencher com dados aleatórios (a chave real)
dd if=/dev/urandom of=/dev/mapper/lukskey bs=1M count=4
```

## Criando Header Detached

```bash
# Criar arquivo para o header (16MB é suficiente)
dd if=/dev/urandom of=/mnt/usb/header.img bs=1M count=16
```

## Criptografando Disco Principal

```bash
# Formatar partição com header detached e keyfile
cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --hash sha512 \
    --key-size 512 \
    --iter-time 10000 \
    --pbkdf argon2id \
    --header /mnt/usb/header.img \
    --key-file /dev/mapper/lukskey \
    ${NVME}p2

# Abrir a partição
cryptsetup luksOpen \
    --header /mnt/usb/header.img \
    --key-file /dev/mapper/lukskey \
    ${NVME}p2 \
    gentoo
```

> **Nota:** Sem o header, a partição ${NVME}p2 é indistinguível de dados aleatórios.

## Criando Btrfs com Subvolumes

```bash
# Formatar
mkfs.btrfs -L "gentoo" /dev/mapper/gentoo

# Montar temporariamente
mount /dev/mapper/gentoo /mnt/gentoo

# Criar subvolumes
btrfs subvolume create /mnt/gentoo/@
btrfs subvolume create /mnt/gentoo/@root
btrfs subvolume create /mnt/gentoo/@home
btrfs subvolume create /mnt/gentoo/@var
btrfs subvolume create /mnt/gentoo/@usr
btrfs subvolume create /mnt/gentoo/@opt

# Listar e anotar IDs
btrfs subvolume list /mnt/gentoo

# Desmontar
umount /mnt/gentoo
```

## Montando Sistema de Arquivos

```bash
# Opções btrfs otimizadas para NVMe
BTRFS_OPTS="rw,noatime,compress=zstd:1,ssd,space_cache=v2,discard=async"

# Montar subvolume principal
mount -t btrfs -o ${BTRFS_OPTS},subvol=@ /dev/mapper/gentoo /mnt/gentoo

# Criar pontos de montagem
mkdir -p /mnt/gentoo/{root,home,var,usr,opt,boot/efi}

# Montar subvolumes
mount -t btrfs -o ${BTRFS_OPTS},subvol=@root /dev/mapper/gentoo /mnt/gentoo/root
mount -t btrfs -o ${BTRFS_OPTS},subvol=@home /dev/mapper/gentoo /mnt/gentoo/home
mount -t btrfs -o ${BTRFS_OPTS},subvol=@var /dev/mapper/gentoo /mnt/gentoo/var
mount -t btrfs -o ${BTRFS_OPTS},subvol=@usr /dev/mapper/gentoo /mnt/gentoo/usr
mount -t btrfs -o ${BTRFS_OPTS},subvol=@opt /dev/mapper/gentoo /mnt/gentoo/opt

# Montar EFI
mount ${NVME}p1 /mnt/gentoo/boot/efi
```

## Fechando Keyfile

```bash
cryptsetup close lukskey
```

## Anotando Informações Importantes

```bash
# PARTUUID da partição criptografada (ANOTAR!)
blkid -s PARTUUID -o value ${NVME}p2

# UUID do btrfs (para fstab)
blkid -s UUID -o value /dev/mapper/gentoo

# UUID da EFI
blkid -s UUID -o value ${NVME}p1
```

## Verificação Final

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT

# Deve mostrar algo como:
# nvme0n1
# ├─nvme0n1p1    512M  part  vfat   /mnt/gentoo/boot/efi
# └─nvme0n1p2    xxxG  part  
#   └─gentoo     xxxG  crypt btrfs  /mnt/gentoo
```

## Segurança do USB

Após a instalação:
- Guarde o USB em local seguro
- Considere fazer backup criptografado do header.img e key.img
- Sem estes arquivos, os dados são irrecuperáveis

## Checklist

- [ ] NVMe particionado (EFI + LUKS)
- [ ] USB preparado com label INTFS_KEY
- [ ] key.img criado e criptografado
- [ ] header.img criado
- [ ] Partição principal criptografada com detached header
- [ ] Btrfs com subvolumes criados
- [ ] Tudo montado em /mnt/gentoo
- [ ] PARTUUID anotado
