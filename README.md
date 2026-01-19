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
- [x] Keyfile criptografado separado
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
│  USB Externo (INTFS_KEY)                                        │
│  ├── key.img      (LUKS encrypted keyfile)                      │
│  └── header.img   (LUKS2 detached header)                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  NVMe Principal                                                 │
│                                                                 │
│  ┌──────────────┐  ┌──────────────────────────────────────────┐ │
│  │ nvme0n1p1    │  │ nvme0n1p2                                │ │
│  │ EFI (512MB)  │  │ LUKS2 (sem header) → btrfs               │ │
│  │ FAT32        │  │                                          │ │
│  │              │  │ Subvolumes:                              │ │
│  │ /boot/efi    │  │   @      → /                             │ │
│  │              │  │   @root  → /root                         │ │
│  │ bzImage.efi  │  │   @home  → /home                         │ │
│  │              │  │   @usr   → /usr                          │ │
│  │              │  │   @var   → /var                          │ │
│  │              │  │   @opt   → /opt                          │ │
│  └──────────────┘  └──────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Fluxo de Boot

```
UEFI → EFI Stub (bzImage.efi) → initramfs → 
  → Aguarda USB → Abre keyfile → Abre LUKS com detached header →
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

- [Gentoo Handbook](https://wiki.gentoo.org/wiki/Handbook:AMD64)
- [Custom Initramfs](https://wiki.gentoo.org/wiki/Custom_Initramfs)
- [Dm-crypt](https://wiki.gentoo.org/wiki/Dm-crypt)
- [Arch Wiki - LUKS Detached Header](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Encrypted_system_using_a_detached_LUKS_header)
- [Gentoo Wiki](https://wiki.gentoo.org/wiki/Custom_Initramfs)
- [EFI Stub](https://wiki.gentoo.org/wiki/EFI_stub)

## Licença

MIT
