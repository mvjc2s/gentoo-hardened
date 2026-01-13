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
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal/install-amd64-minimal-*.iso

# Verificar
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal/install-amd64-minimal-*.iso.sha256
sha256sum -c install-amd64-minimal-*.iso.sha256
```

### Opção 2: SystemRescue (mais ferramentas)
```bash
wget https://fastly-cdn.system-rescue.org/releases/systemrescue-*.iso
```

## Planejamento de Partições

### NVMe Principal
| Partição | Tamanho | Tipo | Uso |
|----------|---------|------|-----|
| nvme0n1p1 | 512MB | EFI System | /boot/efi |
| nvme0n1p2 | Resto | Linux filesystem | LUKS → btrfs |

### USB de Secrets
| Arquivo | Tamanho | Descrição |
|---------|---------|-----------|
| key.img | 4MB | Keyfile LUKS encrypted |
| header.img | 16MB | LUKS2 header |

## Identificando Dispositivos

```bash
# Listar todos os discos
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Identificar NVMe
ls -la /dev/nvme*

# Identificar USB
ls -la /dev/sd*

# Detalhes com parted
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

# Testar
ping -c 3 gentoo.org
```

## Sincronizando Relógio

```bash
# Importante para verificação de assinaturas
ntpd -q -g

# Ou manualmente
date MMDDhhmmYYYY
```

## Obtendo PARTUUID (para depois)

Após particionar, anote o PARTUUID:

```bash
blkid -s PARTUUID -o value /dev/nvme0n1p2
```

Este valor será usado no script init do initramfs.

## Checklist

- [ ] Live environment bootado
- [ ] Rede funcionando
- [ ] Dispositivos identificados (NVMe e USB)
- [ ] Relógio sincronizado
- [ ] Backup feito (se necessário)
