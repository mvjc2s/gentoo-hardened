# Gentoo Linux - Lenovo LOQ Installation

Instalação minimal do Gentoo Linux com profile hardened, LUKS2 com detached header, btrfs, e UEFI stub boot.

## Hardware

- **Modelo:** Lenovo LOQ
- **CPU:** Intel/AMD (ajustar conforme modelo específico)
- **GPU:** NVIDIA RTX 2050 + Intel/AMD iGPU (Optimus)
- **Storage:** NVMe

## Features

- [x] Profile hardened
- [x] Full disk encryption (LUKS2)
- [x] Detached LUKS header em USB externo
- [x] Keyfile separado com deniability
- [x] Btrfs com subvolumes
- [x] UEFI stub boot (sem GRUB)
- [x] Custom initramfs
- [x] NVIDIA Optimus (prime-run)

## Estrutura do Repositório

```
.
├── docs/                       # Documentação passo-a-passo
│   ├── 00-preparacao.md        # Preparação e planejamento
│   ├── 01-particionamento.md   # Particionamento e LUKS
│   ├── 02-instalacao-base.md   # Instalação do stage3
│   ├── 03-kernel.md            # Configuração do kernel
│   ├── 04-initramfs.md         # Custom initramfs
│   ├── 05-efibootmgr.md        # UEFI boot direto
│   └── 06-nvidia-optimus.md    # Configuração GPU híbrida
├── initramfs/                  # Arquivos do initramfs
│   ├── init                    # Script de inicialização
│   ├── initramfs.list          # Especificação de arquivos
│   ├── build.sh                # Script de build
│   └── src/                    # Arquivos auxiliares
├── configs/                    # Configurações do sistema
│   ├── kernel/                 # .config do kernel
│   ├── portage/                # make.conf, package.use, etc.
│   └── efi/                    # Scripts efibootmgr
└── scripts/                    # Scripts auxiliares
    ├── chroot-setup.sh         # Preparação do chroot
    └── post-install.sh         # Pós-instalação
```

## Esquema de Disco

```
┌─────────────────────────────────────────────────────────────────┐
│  USB Externo (EFI e SECRETS)                                    │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ /dev/sda1 (EFI)                                            │ │
|  | ...                                                        | |
│  │  ├── bzImage.efi (\EFI\Gentoo)                             | |
│  └────────────────────────────────────────────────────────────┘ │
|                                                                 |
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ /dev/sda2 (SECRETS)                                        │ │
|  |                                                            | |
|  | /dev/mapper/secrets                                        | |
│  |  ├── cache.dat      (LUKS2 encrypted keyfile)              | │
│  |  └── index.dat      (LUKS2 detached header)                | │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  NVMe Principal Partitionless (Sistema)                         │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ /dev/nvme1n1 (GENTOO)                                      │ │
│  │                                                            | |
│  │ Subvolumes (/dev/mapper/gentoo):                           │ │
│  │  @      → /                                                │ │
│  │  @root  → /root                                            │ │
│  │  @home  → /home                                            | │
│  │  @usr   → /usr                                             │ │
│  │  @var   → /var                                             │ │
│  │  @opt   → /opt                                             │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Fluxo de Boot

```
UEFI → EFI Stub (bzImage.efi) → initramfs → 
      → Aguarda USB → Abre container USB → Abre container do Sistema →
  → Monta btrfs → switch_root → OpenRC → Sistema
```

## Segurança

O detached header oferece:

1. **Deniability** - Sem o header, a partição é indistinguível de dados aleatórios
2. **Two-factor** - Precisa do USB físico + senha para descriptografar
3. **Header backup seguro** - Header pode ser guardado em local seguro separado

## Quick Start

1. Clone o repositório
2. Siga os docs em ordem numérica
3. Ajuste as configurações para seu hardware específico

## Referências

- [Gentoo Wiki - Gentoo Handbook](https://wiki.gentoo.org/wiki/Handbook:AMD64)
- [Gentoo Wiki - Security Handbook](https://wiki.gentoo.org/wiki/Security_Handbook)
- [Gentoo Wiki - Hardened Gentoo](https://wiki.gentoo.org/wiki/Hardened_Gentoo)
- [Gentoo Wiki - User:SwifT/Complete Handbook](https://wiki.gentoo.org/wiki/User:SwifT/Complete_Handbook)
- [Gentoo Wiki - Installation](https://wiki.gentoo.org/wiki/Installation)
- [Gentoo Wiki - Swap](https://wiki.gentoo.org/wiki/Swap)
- [Gentoo Wiki - Remote shell access](https://wiki.gentoo.org/wiki/User:SwifT/Complete_Handbook/Starting_from_minimal_environment#Remote_shell_access)
- [Gentoo Wiki - Kernel Configuration Guide](https://wiki.gentoo.org/wiki/Kernel/Gentoo_Kernel_Configuration_Guide)
- [Gentoo Wiki - Signed kernel module support](https://wiki.gentoo.org/wiki/Signed_kernel_module_support)
- [Gentoo Wiki - AppArmor](https://wiki.gentoo.org/wiki/Security_Handbook/Linux_Security_Modules/AppArmor)
- [Gentoo Wiki - Initramfs](https://wiki.gentoo.org/wiki/Kernel/Gentoo_Kernel_Configuration_Guide)
- [Gentoo Wiki - Custom Initramfs](https://wiki.gentoo.org/wiki/Custom_Initramfs)
- [Gentoo Wiki - NVIDIA](https://wiki.gentoo.org/wiki/NVIDIA)
- [Gentoo Wiki - NVIDIA/nvidia-drivers](https://wiki.gentoo.org/wiki/NVIDIA/nvidia-drivers)
- [Gentoo Wiki - Custom Initramfs](https://wiki.gentoo.org/wiki/Custom_Initramfs)
- [Gentoo Wiki - Dm-crypt](https://wiki.gentoo.org/wiki/Dm-crypt)
- [Arch Wiki - LUKS Detached Header](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Encrypted_system_using_a_detached_LUKS_header)
- [Gentoo Wiki - Install Gentoo on a bootable USB stick](https://wiki.gentoo.org/wiki/Install_Gentoo_on_a_bootable_USB_stick)
- [Gentoo Wiki - EFI Stub](https://wiki.gentoo.org/wiki/EFI_stub)
- [Gentoo Wiki - Portage TMPDIR on tmpfs](https://wiki.gentoo.org/wiki/Portage_TMPDIR_on_tmpfs)
- [Kernel.org - Admin Guide for Devices](https://www.kernel.org/doc/Documentation/admin-guide/devices.txt)
- [Gentoo Forums - \[SOLVED\] Menuconfig or nconfig?](https://forums.gentoo.org/viewtopic-t-1165878-view-previous.html?sid=9bb5464b4bc1fac95f086993efc8b92b)

## Licença

MIT
