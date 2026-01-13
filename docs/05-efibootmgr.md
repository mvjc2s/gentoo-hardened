# 05 - UEFI Boot (efibootmgr)

## Visão Geral

Usamos EFI stub boot direto, sem bootloader intermediário (GRUB, systemd-boot, etc). O kernel é carregado diretamente pelo UEFI.

Vantagens:
- Menos componentes = menor superfície de ataque
- Boot mais rápido
- Sem configuração de bootloader para manter

Desvantagens:
- Parâmetros de kernel devem ser embutidos ou passados via UEFI
- Dual boot mais complexo (mas possível)

## Estrutura EFI

```
/boot/efi/                      # Montado de nvme0n1p1
└── EFI/
    └── Gentoo/
        ├── bzImage.efi         # Kernel com initramfs embutido
        └── bzImage.efi.old     # Backup do kernel anterior
```

## Instalação do efibootmgr

```bash
emerge --ask sys-boot/efibootmgr
```

## Verificando Variáveis UEFI

```bash
# Verificar se efivarfs está montado
mount | grep efivars
# Se não estiver:
mount -t efivarfs efivarfs /sys/firmware/efi/efivars

# Listar entradas de boot existentes
efibootmgr -v
```

## Criando Entrada de Boot

```bash
# Identificar disco EFI
# Geralmente /dev/nvme0n1 partição 1
DISK=/dev/nvme0n1
PART=1

# Criar entrada de boot
efibootmgr \
    --create \
    --disk $DISK \
    --part $PART \
    --label "Gentoo Linux" \
    --loader '\EFI\Gentoo\bzImage.efi' \
    --verbose

# Verificar
efibootmgr -v
```

## Parâmetros de Kernel

Existem duas formas de passar parâmetros:

### Opção 1: Embutido no Kernel (recomendado)

No menuconfig do kernel:
```
Processor type and features --->
    [*] Built-in kernel command line
    (root=/dev/mapper/gentoo ro quiet) Built-in kernel command string
```

Parâmetros típicos:
```
root=/dev/mapper/gentoo ro quiet
```

> Nota: Com o initramfs customizado, o root real é montado pelo init script, então este parâmetro é mais informativo do que funcional.

### Opção 2: Via efibootmgr (limitado)

Alguns firmwares suportam passar parâmetros via UEFI:

```bash
efibootmgr \
    --create \
    --disk /dev/nvme0n1 \
    --part 1 \
    --label "Gentoo Linux" \
    --loader '\EFI\Gentoo\bzImage.efi' \
    --unicode 'root=/dev/mapper/gentoo ro quiet'
```

## Gerenciando Entradas

```bash
# Listar entradas
efibootmgr

# Exemplo de saída:
# BootCurrent: 0001
# BootOrder: 0001,0000,0002
# Boot0000* Windows Boot Manager
# Boot0001* Gentoo Linux
# Boot0002* UEFI Shell

# Alterar ordem de boot
efibootmgr --bootorder 0001,0000,0002

# Definir próximo boot único
efibootmgr --bootnext 0000

# Remover entrada
efibootmgr --delete-bootnum --bootnum 0003

# Ativar/desativar entrada
efibootmgr --inactive --bootnum 0002
efibootmgr --active --bootnum 0002
```

## Backup do Kernel

Script para atualizar kernel com backup:

```bash
#!/bin/bash
# /usr/local/sbin/update-kernel.sh

EFI_DIR="/boot/efi/EFI/Gentoo"
KERNEL_SRC="/usr/src/linux"

# Backup do kernel atual
if [[ -f "$EFI_DIR/bzImage.efi" ]]; then
    cp "$EFI_DIR/bzImage.efi" "$EFI_DIR/bzImage.efi.old"
    echo "Backup criado: bzImage.efi.old"
fi

# Copiar novo kernel
cp "$KERNEL_SRC/arch/x86_64/boot/bzImage" "$EFI_DIR/bzImage.efi"
echo "Novo kernel instalado"

# Salvar config
cp "$KERNEL_SRC/.config" "/boot/config-$(date +%Y%m%d)"
```

## Entrada de Boot para Kernel de Backup

```bash
# Criar entrada para kernel antigo (emergência)
efibootmgr \
    --create \
    --disk /dev/nvme0n1 \
    --part 1 \
    --label "Gentoo Linux (backup)" \
    --loader '\EFI\Gentoo\bzImage.efi.old'
```

## Secure Boot (Opcional)

Se quiser habilitar Secure Boot:

```bash
# Instalar ferramentas
emerge --ask app-crypt/sbsigntools app-crypt/efitools

# Gerar chaves
mkdir -p /etc/efi-keys
cd /etc/efi-keys
openssl req -new -x509 -newkey rsa:2048 -keyout MOK.key -out MOK.crt -nodes -days 3650 -subj "/CN=Gentoo Machine Owner Key/"
openssl x509 -in MOK.crt -out MOK.cer -outform DER

# Assinar kernel
sbsign --key /etc/efi-keys/MOK.key --cert /etc/efi-keys/MOK.crt --output /boot/efi/EFI/Gentoo/bzImage.efi /usr/src/linux/arch/x86_64/boot/bzImage

# Registrar MOK no firmware
mokutil --import /etc/efi-keys/MOK.cer
# Reboot e seguir instruções na tela
```

## Troubleshooting

### "EFI variables not supported"
```bash
# Verificar se UEFI está disponível
ls /sys/firmware/efi

# Montar efivarfs
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
```

### Boot entry não aparece
- Verificar se o caminho do loader está correto (usar \ não /)
- Verificar se a partição EFI está marcada como ESP
- Alguns firmwares só detectam `\EFI\BOOT\BOOTX64.EFI`

### Fallback para firmware
```bash
# Copiar kernel para local padrão
mkdir -p /boot/efi/EFI/BOOT
cp /boot/efi/EFI/Gentoo/bzImage.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
```

## Checklist

- [ ] efibootmgr instalado
- [ ] efivarfs montado
- [ ] Kernel copiado para /boot/efi/EFI/Gentoo/
- [ ] Entrada de boot criada
- [ ] Boot order configurado
- [ ] Entrada de backup criada (opcional)
- [ ] Testado boot sem mídia de instalação
