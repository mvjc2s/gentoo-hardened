# 00 - Preparação

## Requisitos

### Hardware
- Lenovo LOQ com NVMe
- USB flash drive (mínimo 16MB para secrets, recomendado 1GB+)
- Outro USB para boot do live environment

### Software (no live environment)
- cryptsetup 2.4+
- parted
- btrfs-progs
- dosfstools

## Obtendo o Live Environment

### Opção 1: Gentoo Minimal Installation CD

```bash
# Download
BASE="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal"
TXT="latest-install-amd64-minimal.txt"
wget $BASE/$TXT
ISO=`cat $TXT | grep minimal | cut -d " " -f1`
wget $BASE/$ISO

# Verificar
FILE=`echo $ISO | cut -d "/" -f2`
wget $BASE/$FILE.{asc,sha256,DIGESTS,CONTENTS.gz}
sha256sum -c $FILE.sha256
gpg --auto-key-locate=clear,nodefault,wkd --locate-key releng@gentoo.org
gpg --verify $FILE.asc
```

### Opção 2: SystemRescue (mais ferramentas)
```bash
BASE="https://fastly-cdn.system-rescue.org/releases"
VERSION="12.03"
FILE="systemrescue-$VERSION-amd64.iso"
wget $BASE/$VERSION/$FILE
wget $BASE/$VERSION/$FILE.{sha512,asc}
sha512sum --check $FILE.sha512
wget https://www.system-rescue.org/security/signing-keys/gnupg-pubkey-fdupoux-20210704-v001.pem
mv gnupg*.pem gnupg-pubkey.txt
gpg --import gnupg-pubkey.txt
gpg --verify $FILE.asc $FILE
```

## Planejamento de Partições

### NVMe Principal
| Partição | Tamanho | Tipo | Uso |
|----------|---------|------|-----|
| sdXx | 1 GiB | EFI System | /boot/efi, contendo kernel e initramfs |
| sdXx | Resto | Linux filesystem | LUKS -> ext4, contendo a chave e o header |

### NVMe Principal
| Partição | Tamanho | Tipo | Uso |
|----------|---------|------|-----|
| nvme0n1 | Resto | Linux filesystem | LUKS -> btrfs |

### Partição LUKS no dispositivo USB para Secrets
| Arquivo | Tamanho | Descrição |
|---------|---------|-----------|
| key.img | 4MB | Keyfile LUKS encrypted |
| header.img | 16MB | LUKS2 header |

## Identificando Dispositivos

```bash
# Listar todos os discos por nome, tamanho e tipo 
lsblk -o NAME,SIZE,TYPE

# Identificar dispositivos NVMe
ls -la /dev/nvme*

# Identificar USB (verificar com extrema atenção)
ls -la /dev/sd*

# Detalhar com parted
parted -l
```

## Backup (se aplicável)

Se estiver reinstalando, faça backup:

```bash
# Montar partição existente (se possível)
# Copiar dados importantes
```

## Configurando Rede no Live

```bash
# DHCP
dhcpcd

# WiFi (se necessário)
wpa_passphrase "SSID" "senha" > /etc/wpa_supplicant.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
dhcpcd wlan0

# Testar conectividade
ping -c 3 gentoo.org
```

## Sincronizando Relógio

```bash
# Importante para verificação de assinaturas
ntpd -q -g

# Ou manualmente (apenas altere para os valores correspondentes nos comandos abaixo)
date MMDDhhmmYYYY
date -s "HH:MM:SS"
```

## Checklist

- [ ] Live environment bootado
- [ ] Rede funcionando
- [ ] Dispositivos identificados (NVMe e USB)
- [ ] Relógio sincronizado
- [ ] Backup feito (se necessário)
