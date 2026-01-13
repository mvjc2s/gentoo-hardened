# 03 - Kernel

## Instalação das Fontes

```bash
# Licença para firmware
echo "sys-kernel/linux-firmware linux-fw-redistributable no-source-code" > /etc/portage/package.license/linux-firmware

# Instalar
emerge --ask sys-kernel/gentoo-sources sys-kernel/linux-firmware

# Selecionar kernel
eselect kernel list
eselect kernel set 1

# Verificar
ls -l /usr/src/linux
```

## Configuração

```bash
cd /usr/src/linux

# Começar com defconfig
make defconfig

# Ou copiar config existente
# cp /path/to/saved/.config .

# Configurar
make menuconfig
```

## Opções Essenciais

### General Setup

```
General setup --->
    [*] Initial RAM filesystem and RAM disk (initramfs/initrd) support
    (/usr/src/initramfs) Initramfs source file(s)
    [ ] Support initial ramdisk/ramfs compressed using gzip
    [ ] Support initial ramdisk/ramfs compressed using bzip2
    [ ] Support initial ramdisk/ramfs compressed using LZMA
    [ ] Support initial ramdisk/ramfs compressed using XZ
    [ ] Support initial ramdisk/ramfs compressed using LZO
    [ ] Support initial ramdisk/ramfs compressed using LZ4
    [*] Support initial ramdisk/ramfs compressed using ZSTD
```

### Processador (Intel ou AMD)

```
Processor type and features --->
    [*] Symmetric multi-processing support
    [*] SMT (Hyperthreading) scheduler support
    [*] Multi-core scheduler support
    
    # Para Intel:
    Processor family (Core 2/newer Xeon) --->
    
    # Para AMD:
    Processor family (AMD Zen) --->
    
    [*] EFI runtime service support
    [*]   EFI stub support
    [ ]     EFI mixed-mode support  # Desabilitar em sistemas 64-bit puros
    [*] Built-in kernel command line
    ()  Built-in kernel command string
```

### Device Mapper e Crypt

```
[*] Enable loadable module support --->

Device Drivers --->
    [*] Multiple devices driver support (RAID and LVM) --->
        <*> Device mapper support
        <*>   Crypt target support
        <*>   Snapshot target
        <*>   Mirror target
    
    [*] Block devices --->
        <*> Loopback device support
```

### Cryptographic API

```
[*] Cryptographic API --->
    <*> XTS support
    <*> SHA224 and SHA256 digest algorithm
    <*> SHA384 and SHA512 digest algorithms
    <*> Whirlpool digest algorithms
    <*> AES cipher algorithms
    <*> AES cipher algorithms (x86_64)
    <*> Serpent cipher algorithm
    <*> User-space interface for hash algorithms
    <*> User-space interface for symmetric key cipher algorithms
    <*> User-space interface for AEAD cipher algorithms
```

### NVMe

```
Device Drivers --->
    <*> NVM Express block device
    [*]   NVMe multipath support
    [*]   NVMe hardware monitoring
    NVME Support --->
        <*> NVM Express block device
```

### Btrfs

```
File systems --->
    <*> Btrfs filesystem support
    [*]   Btrfs POSIX Access Control Lists
    
    DOS/FAT/NT Filesystems --->
        <*> VFAT (Windows-95) fs support
    
    Pseudo filesystems --->
        [*] /proc file system support
        [*] Tmpfs virtual memory file system support
```

### EFI

```
Firmware Drivers --->
    EFI (Extensible Firmware Interface) Support --->
        <*> EFI Variable Support via sysfs
        [*] Export efi runtime maps to sysfs

-*- Enable the block layer --->
    Partition Types --->
        [*] Advanced partition selection
        [*] EFI GUID Partition support
```

### USB (para USB de secrets)

```
Device Drivers --->
    [*] USB support --->
        <*> Support for Host-side USB
        <*>   xHCI HCD (USB 3.0) support
        <*>   EHCI HCD (USB 2.0) support
        <*>   OHCI HCD (USB 1.1) support
        <*> USB Mass Storage support
    
    HID support --->
        <*> HID bus support
        <*>   Generic HID driver
        [*]   Battery level reporting for HID devices
        USB HID support --->
            <*> USB HID transport layer
```

### NVIDIA (para depois, não no initramfs)

```
Device Drivers --->
    Graphics support --->
        <*> Direct Rendering Manager (XFree86 4.1.0 and higher DRI support)
        [*]   Enable legacy fbdev support for your modesetting driver
        
        # Intel iGPU (se aplicável)
        <*> Intel 8xx/9xx/G3x/G4x/HD Graphics
        
        # Frame buffer (para console)
        <*> Support for frame buffer devices --->
            [*] EFI-based Framebuffer Support
```

### Hardening (opcional mas recomendado)

```
Security options --->
    [*] Enable different security models
    [*] Socket and Networking Security Hooks
    [*] NSA SELinux Support  # Ou AppArmor
    
    Kernel hardening options --->
        Memory initialization --->
            [*] Initialize kernel stack variables at function entry
            [*] Poison kernel stack before returning from syscalls
        [*] Randomize the address of the kernel image (KASLR)
        [*] Randomize the kernel memory sections
```

## Compilação

```bash
# Compilar
make -j$(nproc)

# Instalar módulos
make modules_install

# Copiar kernel para EFI
mkdir -p /boot/efi/EFI/Gentoo
cp arch/x86_64/boot/bzImage /boot/efi/EFI/Gentoo/bzImage.efi

# Salvar config
cp .config /boot/config-$(make kernelrelease)
```

## Verificação

```bash
# Verificar se initramfs foi embarcado
ls -lh /boot/efi/EFI/Gentoo/bzImage.efi

# O tamanho deve ser maior que o kernel sozinho (incluindo initramfs)
# Geralmente 10-30MB dependendo do que está incluído
```

## Rebuild após mudanças no initramfs

Se modificar o initramfs:

```bash
cd /usr/src/linux
make -j$(nproc)
cp arch/x86_64/boot/bzImage /boot/efi/EFI/Gentoo/bzImage.efi
```

## Checklist

- [ ] gentoo-sources instalado
- [ ] linux-firmware instalado
- [ ] Kernel configurado com todas opções necessárias
- [ ] Initramfs source apontando para /usr/src/initramfs
- [ ] Crypto API completa para LUKS2
- [ ] NVMe habilitado
- [ ] USB mass storage habilitado
- [ ] Btrfs habilitado
- [ ] EFI stub habilitado
- [ ] Kernel compilado
- [ ] bzImage copiado para EFI
