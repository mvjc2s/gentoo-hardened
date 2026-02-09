# 01 - Particionamento e LUKS

## Visão Geral

Este setup usa:
- LUKS2 com detached header (header em USB externo)
- Keyfile separado também criptografado
- Sem header no disco principal = plausible deniability

## Acesso remoto com SSH

```
O acesso remoto é um grande facilitador para copiarmos e colarmos texto,
geralmente termos uma interface gráfica externa para navegar melhor pela
documentação, além de vários outros benefícios. Portanto, é preferível
utilizar o SSH. Todavia, caso não tenha esta possibilidade, pode utilizar
outra ferramenta como o comando screen, ou simplesmente faça tudo na unha
mesmo em um português claro.
```

```
Precisamos fazer algumas configurações importantes no arquivo /etc/sshd_config
antes de nos subirmos ao nosso servidor SSH, e são elas:

1 - Port 22222 => Caso tenha algum firewall ou outra solução de segurança,
mude para uma porta alternativa;
2 - PermitRootLogin yes => Permita o login no servidor SSH como usuário root;
3 - PasswordAuthentication yes => Permita a autenticação por meio de senha.
```

### /etc/ssh/sshd_config

```
...
Port 22222
...
PermitRootLogin yes
...
PasswordAuthentication yes
...
```

```bash
# Crie uma senha para o usuário root
passwd

# Inicie o serviço (daemon) SSH e verifique o seu IP local
rc-service sshd start && ifconfig

# No sistema-cliente ao qual será usado para acessar o nosso serviço SSH, use o comando abaixo apenas substituindo para o seu IP:
ssh root@[IP] -p 22222
```

## Preparação do dispositivo NVMe

```bash
# Configurar a variável NVME contendo o dispositivo NVMe para o sistema
NVME=/dev/nvme0n1

# Subscrever os dados do dispositivo NVMe (opcional; se o disco é muito grande, é recomendado aumentar de forma proporcional o valor de 512 bytes)
dd if=/dev/urandom of=$NVME bs=512 status=progress && sync
```

## Preparando USB para EFI e Secrets

```bash
# Identificar USB
USB=/dev/sdx  # CUIDADO: verificar com lsblk (ver docs/00-preparacao.md)

# Subscrever os dados do dispositivo USB (opcional)
dd if=/dev/urandom of=$USB bs=512 status=progress && sync

# Criar partição EFI
parted -a optimal $USB mklabel gpt
parted -a optimal $USB mkpart primary fat32 1MiB 1026MiB 
parted $USB set 1 esp on

# Criar partição LUKS para as Secrets
parted -a optimal $USB mkpart primary 1026MiB 100%

# Formatar com label específica
mkfs.vfat -F32 -n "EFI" ${USB}1

# Criptografar a partição para as Secrets
cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --hash sha512 \
    --key-size 512 \
    --iter-time 2500 \
    --pbkdf argon2id \
    ${USB}2

# Descriptografar a partição para as Secrets
cryptsetup luksOpen ${USB}2 secrets

# Formatar a partição para as Secrets
mkfs.ext4 -v -L "KEYS" /dev/mapper/secrets

# Montar
mkdir /mnt/secrets
mount /dev/mapper/secrets /mnt/secrets
```

## Criando Keyfile Criptografado

O keyfile é um arquivo pequeno, criptografado com LUKS, que contém dados aleatórios usados como chave para o disco principal.

```bash
# Mude para o diretório /mnt/usb
cd /mnt/secrets

# Criar arquivo de 4MB com dados aleatórios
dd if=/dev/urandom of=key.img bs=1M count=4

# Criptografar o keyfile
cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --hash sha512 \
    --key-size 512 \
    --iter-time 2500 \
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
dd if=/dev/urandom of=/mnt/secrets/header.img bs=1M count=16
```

## Criptografando Disco Principal

```bash
# Criptografar o NVMe utilizando o  header detached e keyfile
cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --hash sha512 \
    --key-size 512 \
    --iter-time 5000 \
    --pbkdf argon2id \
    --header /mnt/secrets/header.img \
    --key-file /dev/mapper/lukskey \
    ${NVME}

# Abrir o dispositivo criptografada (mapper)
cryptsetup luksOpen \
    --header /mnt/secrets/header.img \
    --key-file /dev/mapper/lukskey \
    ${NVME} \
    gentoo
```

> **Nota:** Sem o header, a partição ${NVME} é indistinguível de dados aleatórios. Além do fato do disco principal para a instalação do sistema Gentoo ser partitionless.

## Criando Btrfs com Subvolumes

```bash
# Formatar o mapeador do sistema
mkfs.btrfs -L "gentoo" /dev/mapper/gentoo

# Montar temporariamente para criação dos subvolumes
mount /dev/mapper/gentoo /mnt/gentoo

# Criar subvolumes
btrfs subvolume create /mnt/gentoo/@
btrfs subvolume create /mnt/gentoo/@root
btrfs subvolume create /mnt/gentoo/@home
btrfs subvolume create /mnt/gentoo/@var
btrfs subvolume create /mnt/gentoo/@usr
btrfs subvolume create /mnt/gentoo/@opt

# Listar e anotar apenas o ID do subvolume-raiz (@)
btrfs subvolume list /mnt/gentoo

# Configurar o ID do subvolume-raiz @ como padrão do sistema
btrfs subvolume set-default <ID> /mnt/gentoo

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
mount -t btrfs -o ${BTRFS_OPTS},nodev,nosuid,subvol=@root /dev/mapper/gentoo /mnt/gentoo/root
mount -t btrfs -o ${BTRFS_OPTS},nodev,nosuid,subvol=@home /dev/mapper/gentoo /mnt/gentoo/home
mount -t btrfs -o ${BTRFS_OPTS},noexec,nodev,nosuid,subvol=@var /dev/mapper/gentoo /mnt/gentoo/var
mount -t btrfs -o ${BTRFS_OPTS},nodev,subvol=@usr /dev/mapper/gentoo /mnt/gentoo/usr
mount -t btrfs -o ${BTRFS_OPTS},nodev,nosuid,subvol=@opt /dev/mapper/gentoo /mnt/gentoo/opt

# Montar EFI
mount ${USB}1 /mnt/gentoo/boot/efi
```

## Fechando LUKS keyfile, desmontando a partição secrets e fechando o mapper

```bash
cryptsetup close lukskey
umount /mnt/secrets
cryptsetup close secretss
```

## Anotando Informações Importantes

```bash
# UUID do btrfs (para fstab)
GENTOO_ID=`blkid -s UUID -o value /dev/mapper/gentoo`
export GENTOO

# UUID da EFI
EFI_ID=`blkid -s UUID -o value ${USB}1`
export EFI
```

## Verificação Final

```bash
# Lista todos os dispositovos pelo nome, tamanho, tipo, tipo de sistema de arquivo e ponto de montagme
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT

# Deve mostrar algo como (EM REVISÃO!):
# sdxX
# ├─sdxX    1026M  part  vfat   /mnt/gentoo/boot/efi
# └─vme0n1p2    xxxG  part  
#   └─gentoo     xxxG  crypt btrfs  /mnt/gentoo
```

## Segurança do USB

Após a instalação:
- Guarde o USB em local seguro
- Considere fazer backup criptografado do header.img e key.img, utilizando a regra de backup 3-2-1, que são: 1. Os arquivos no partição criptografada; 2. Cópia 1 (Local): Salvar em um dispositivo diferente (pendrive ou HD externo); 3. Cópia 2 (Nuvem): Armazenar em um serviço de nuvem (Google Drive, OneDrive, Dropbox)
- Sem estes arquivos, os dados são irrecuperáveis, então, é importantíssimo a redundância de backup destes arquivos

## Checklist

- [ ] USB preparado com duas partições (EFI + LUKS -> ext4, nomeada como KEYS para as Secrets)
- [ ] key.img criado e criptografado
- [ ] header.img criado
- [ ] NVMe partitionless criptogrado com detached header
- [ ] Btrfs com subvolumes criados
- [ ] Tudo montado em /mnt/gentoo
- [ ] UUID das partição EFI e mapper do sistema anotados para construção do /etc/fstab posteriormente
