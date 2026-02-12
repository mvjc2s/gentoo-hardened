# 03 - Kernel

## Instalação das Fontes

```bash
# Licença para firmware
mkdir /etc/portage/package.license
echo "sys-kernel/linux-firmware linux-fw-redistributable" > /etc/portage/package.license/linux-firmware
echo "sys-firmware/intel-microcode intel-ucode" > /etc/portage/portage.license/intel-microcode

# Instalar gentoo-sources, linux-firmware, intel-microcode e sof-firmware
emerge --ask sys-kernel/gentoo-sources sys-kernel/linux-firmware sys-firmware/intel-microcode sys-firmware/sof-firmware

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
# OU, um método de detecção automática dos módulos que estão sendo usados no installcd, o que pode ser um bom ponto de partida, permitindo o usuário a configurar do jeito que deseja
make localmodconfig

# Para configurar com ajuste fino, temos as seguintes opções. Use o que mais gostar dentre elas:

# Todos deveriam experimentar pelo menos uma vez:
make config

# Este comando a seguir, é o próximo passo como possibilidade:
make menuconfig

# E, mais outra:
make nconfig

# Depois, existem ainda as interfaces gráficas:

# X
make xconfig
# Gnome
make gconfig
# QT
make qconfig
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

Gentoo Linux --->
    [*] Gentoo Linux support
    [*] Linux dynamic and persistent device naming (userspace devfs) support
    [*] Select options required by Portage features
    Support for init systems, system and service managers  --->
        [*] OpenRC, runit and other script based systems and managers
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
    [*] EFI stub support
    [ ] EFI mixed-mode support  # Desabilitar em sistemas 64-bit puros
    [*] Built-in kernel command line
    ()  Built-in kernel command string

Binary Emulations --->
    [*] IA32 Emulation
```

### Device Mapper, Crypt, NVMe, USB e entre outros dispositivos

```
[*] Enable loadable module support --->

Device Drivers --->
    [*] Multiple devices driver support (RAID and LVM) --->
        <*> Device mapper support
        <*> Crypt target support
        <*> Snapshot target
        <*> Mirror target
    SCSI device support  ---> 
        <*> SCSI device support
        <*> SCSI disk support

    <*> Serial ATA and Parallel ATA drivers (libata)  --->
        [*] ATA ACPI Support
        [*] SATA Port Multiplier support
        <*> AHCI SATA support (ahci)
        [*] ATA BMDMA support
        [*] ATA SFF support (for legacy IDE and PATA)
        <*> Intel ESB, ICH, PIIX3, PIIX4 PATA/SATA support (ata_piix)

    <*> NVM Express block device
    [*] NVMe multipath support
    [*] NVMe hardware monitoring
    <M> NVM Express over Fabrics FC host driver
    <M> NVM Express over Fabrics TCP host driver
    <M> NVMe Target support
    [*] NVMe Target Passthrough support
    <M> NVMe loopback device support
    <M> NVMe over Fabrics FC target driver
    < > NVMe over Fabrics FC Transport Loopback Test driver (NEW)
    <M> NVMe over Fabrics TCP target support
    NVME Support --->
        <*> NVM Express block device

    Generic Driver Options --->
        [*] Maintain a devtmpfs filesystem to mount at /dev
        [*]   Automount devtmpfs at /dev, after the kernel mounted the rootfs

    HID support --->
        <*> HID bus support
        <*> Generic HID driver
        [*] Battery level reporting for HID devices
        USB HID support --->
           <*> USB HID transport layer
        [*] Block devices --->
           <*> Loopback device support
        [*] USB support --->
           <*> Support for Host-side USB
           <*> EHCI HCD (USB 2.0) support
           <*> xHCI HCD (USB 3.0) support
           <*> OHCI HCD (USB 1.1) support
           <*> USB Mass Storage support
        <*> Unified support for USB4 and Thunderbolt  --->

    Network device support --->
        <*> PPP (point-to-point protocol) support
        <*> PPP over Ethernet
        <*> PPP support for async serial ports
        <*> PPP support for sync tty ports
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

### Sistemas de arquivos e Btrfs

```
File systems --->
    <*> The Extended 3 (ext3) filesystem
    <*> The Extended 4 (ext4) filesystem
    <*> Btrfs filesystem support
    [*]   Btrfs POSIX Access Control Lists
    
    DOS/FAT/NT Filesystems --->
        <*> MSDOS fs support
        <*> VFAT (Windows-95) fs support
    
    Pseudo filesystems --->
        [*] /proc file system support
        [*] Tmpfs virtual memory file system support
        <*> EFI Variable filesystem
```

### EFI e configurações de esquema de partição

```
Firmware Drivers --->
    EFI (Extensible Firmware Interface) Support --->
        <*> EFI Variable Support via sysfs
        [*] Export efi runtime maps to sysfs

Device Drivers --->
    Graphics support  --->
        Frame buffer Devices  --->
            <*> Support for frame buffer devices  --->
                [*]   EFI-based Framebuffer Support
    Sound card support --->
        Advanced Linux Sound Architecture --->
            <M> ALSA for SoC audio support --->
            [*] Sound Open Firmware Support --->
                <M> SOF PCI enumeration support
                <M> SOF ACPI enumeration support
                <M> SOF support for AMD audio DSPs
                [*] SOF support for Intel audio DSPs


Processor type and features  --->
    [*] EFI runtime service support 
    [*]   EFI stub support
    [*]     EFI mixed-mode support

-*- Enable the block layer --->
    Partition Types --->
        [*] Advanced partition selection
        [*] EFI GUID Partition support
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

### Assinar os módulos do kernel

```
[*] Enable loadable module support  
  -*-   Module signature verification    
    [*]     Require modules to be validly signed
    [*]     Automatically sign all modules    
    Which hash algorithm should modules be signed with? (Sign modules with SHA-512) --->
```

## RECOMENDADO: Para usar uma chave customizada, especifique esta chave em CONFIG_MODULE_SIG_KEY.

```bash
# OPENSSL fará algumas questões importantes sobre o usuário que está gerando a chave, é recomendado
# responder estas questões de maneira apropriada, sendo o mais detalhado possível.
openssl req -new -nodes -utf8 -sha256 -x509 -outform PEM -out kernel_key.pem -keyout kernel_key.pem

# Armazene a chave em um local seguro, ao menos a chave deve ser lida somente pelo usuário root do
# sistema. Portanto, verifique...
ls -l kernel_key.pem

# Caso não esteja, somente em modo leitura para o usuário root, use os seguintes comandos abaixo:
chown root:root kernel_key.pem
chmod 400 kernel_key.pem
```

### Configurar a chave do Kernel

```
-*- Cryptographic API  ---> 
    Certificates for signature checking  --->  
      (/path/to/kernel_key.pem) File name or PKCS#11 URI of module signing key
```

### Para assinar módulos externos do Kernel instalado por outros pacotes por linux-mod-r1.eclass, habilite a modules-sign USE flag globalmente em /etc/portage/make.conf:

```
USE="modules-sign"

# Optionally, when using custom signing keys.
MODULES_SIGN_KEY="/path/to/kernel_key.pem"
MODULES_SIGN_CERT="/path/to/kernel_key.pem" # Only required if the MODULES_SIGN_KEY does not also contain the certificate
MODULES_SIGN_HASH="sha512" # Defaults to sha512
```

## OPCIONAL, mas RECOMENDADO: Assinar a imagem do Kernel (Secure Boot)

### Lockdown para Secure boot

```
# Quando assinar a imagem do Kernel, é recomendado configurar as seguintes opções de configuração do kernel:

General setup  --->
    Kexec and crash features  --->   
        [*] Enable kexec system call                                                                                          
        [*] Enable kexec file based system call                                                                               
        [*]   Verify kernel signature during kexec_file_load() syscall                                                        
        [*]     Require a valid signature in kexec_file_load() syscall                                                        
        [*]     Enable ""image"" signature verification support  

[*] Enable loadable module support  
    -*-   Module signature verification    
        [*]     Require modules to be validly signed
        [*]     Automatically sign all modules
        Which hash algorithm should modules be signed with? (Sign modules with SHA-512) --->  

Security options  ---> 
    [*] Integrity subsystem   
    [*] Basic module for enforcing kernel lockdown                                                                       
    [*]   Enable lockdown LSM early in init                                                                       
        Kernel default lockdown mode (Integrity)  --->            

    [*]   Digital signature verification using multiple keyrings                                                            
    [*]     Enable asymmetric keys support                                                                                     
    -*-       Require all keys on the integrity keyrings be signed                                                              
    [*]       Provide keyring for platform/firmware trusted keys                                                                
    [*]       Provide a keyring to which Machine Owner Keys may be added                                                        
    [ ]         Enforce Machine Keyring CA Restrictions
```


```bash
# Após a compilação do Kernel, como explicado na próxima seção, a imagem do Kernel deve ser assinada. Primeiro, isntale app-crypt/sbsigntools e, então assine a imagem do Kernel:
emerge --ask app-crypt/sbsigntools
sbsign /usr/src/linux-x.y.z/path/to/kernel-image --cert /path/to/kernel_key.pem --key /path/to/kernel_key.pem --output /usr/src/linux-x.y.z/path/to/kernel-image
```

### Configuração adicional da USE flag secureboot

```
# Para assinar assinar os executáveis EFI instalado por outros pacotes, habilite a USE flag secureboot globalmente em /etc/portage/make.conf:

USE="modules-sign secureboot"

# Optionally, to use custom signing keys.
MODULES_SIGN_KEY="/path/to/kernel_key.pem"
MODULES_SIGN_CERT="/path/to/kernel_key.pem" # Only required if the MODULES_SIGN_KEY does not also contain the certificate.
MODULES_SIGN_HASH="sha512" # Defaults to sha512

# Optionally, to boot with secureboot enabled, may be the same or different signing key.
SECUREBOOT_SIGN_KEY="/path/to/kernel_key.pem"
SECUREBOOT_SIGN_CERT="/path/to/kernel_key.pem"
```

## Compilação

```bash
# Compilar e instalar módulos
make && make modules_install

# Instalar o kernel
make install

# Copiar kernel para EFI
mkdir -p /boot/efi/EFI/Gentoo
cp arch/x86_64/boot/bzImage /boot/efi/EFI/Gentoo/bzImage.efi

# Salvar config da versão da versão do kernel instalada
cp .config /boot/config-$(make kernelrelease)
```

## Verificação

```bash
# Verificar se initramfs foi copiado adequadamente para a partição EFI
ls -lh /boot/efi/EFI/Gentoo/bzImage.efi

# O tamanho deve ser maior que o kernel sozinho (incluindo initramfs)
# Geralmente 10-30MB dependendo do que está incluído
```

## Rebuild após mudanças no initramfs

```bash
# Se modificar o initramfs, basta executar os comandos abaixo:
cd /usr/src/linux
make
cp arch/x86_64/boot/bzImage /boot/efi/EFI/Gentoo/bzImage.efi
```

## INFO: Listando módulos disponíveis do kernel

```bash
# Os módulos que precisam ser carregados durante cada inicialização podem ser adicionados aos arquivos `/etc/modules-load.d/*.conf` no formato de um módulo por linha. Quando opções extras forem necessárias para os módulos, elas devem ser definidas nos arquivos `/etc/modprobe.d/*.conf`.

# Para visualizar todos os módulos disponíveis para uma versão específica do kernel, execute o seguinte comando `find`. Não se esqueça de substituir "<versão do kernel>" pela versão apropriada do kernel a ser pesquisada:

find /lib/modules/<versão do kernel>/ -type f -iname '*.o' -or -iname '*.ko' | less
```

## Forçar o carregamento de módulos específicos do kernel

```bash
# Para forçar o carregamento do módulo `3c59x.ko` pelo kernel (que é o driver para uma família específica de placas de rede 3Com), edite o arquivo `/etc/modules-load.d/network.conf` e insira o nome do módulo nele.

mkdir -p /etc/modules-load.d
nano -w /etc/modules-load.d/network.conf

# Observe que a extensão .ko do arquivo do módulo é irrelevante para o mecanismo de carregamento e foi omitida do arquivo de configuração em /etc/modules-load.d/network.conf:

3c59x
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
