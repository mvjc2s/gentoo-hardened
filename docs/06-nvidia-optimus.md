# 06 - NVIDIA Optimus

## Visão Geral

O Lenovo LOQ possui GPU híbrida:
- **iGPU:** Intel ou AMD (uso diário, economia de energia)
- **dGPU:** NVIDIA RTX 2050 (jogos, CUDA, renderização)

Abordagens disponíveis:
1. **PRIME Render Offload** (recomendado) - iGPU por padrão, dGPU sob demanda
2. **Reverse PRIME** - dGPU por padrão
3. **Bumblebee** - Legado, não recomendado

## Configuração de USE flags

```bash
cat > /etc/portage/package.use/nvidia << 'EOF'
# Driver NVIDIA
x11-drivers/nvidia-drivers modules tools

# Mesa para iGPU
media-libs/mesa -video_cards_nouveau video_cards_intel vulkan

# Wayland (se usar)
gui-libs/egl-wayland X
EOF
```

## Instalação dos Drivers

```bash
# Aceitar licença NVIDIA
echo "x11-drivers/nvidia-drivers NVIDIA-r2" >> /etc/portage/package.license/nvidia

# Kernel headers (necessário para módulo)
emerge --ask sys-kernel/linux-headers

# Instalar drivers
emerge --ask x11-drivers/nvidia-drivers

# Para Intel iGPU adicional
emerge --ask x11-drivers/xf86-video-intel  # X11
# ou apenas mesa para Wayland

# Para AMD iGPU
# emerge --ask x11-drivers/xf86-video-amdgpu
```

## Configuração do Kernel

```bash
# Módulo NVIDIA precisa de:
Device Drivers --->
    Graphics support --->
        <M> Direct Rendering Manager (XFree86 4.1.0 and higher DRI support)
        
        # Desabilitar nouveau
        < > Nouveau (NVIDIA) cards
        
        # Intel iGPU
        <*> Intel 8xx/9xx/G3x/G4x/HD Graphics
        
        # Frame buffer
        Frame buffer Devices --->
            [*] Support for frame buffer device drivers
            <*> EFI-based Framebuffer Support
```

Após modificar o kernel:
```bash
cd /usr/src/linux
make -j$(nproc)
make modules_install
cp arch/x86_64/boot/bzImage /boot/efi/EFI/Gentoo/bzImage.efi
```

## Módulos e Blacklist

```bash
# Blacklist nouveau
cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

# Configurar módulo nvidia
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1
EOF

# Carregar módulos no boot
cat > /etc/modules-load.d/nvidia.conf << 'EOF'
nvidia
nvidia-modeset
nvidia-drm
nvidia-uvm
EOF

# Rebuild initramfs se necessário
# (não é necessário para nosso setup, módulos carregam depois)
```

## PRIME Render Offload (X11)

### Configuração Xorg

```bash
cat > /etc/X11/xorg.conf.d/10-nvidia-prime.conf << 'EOF'
Section "ServerLayout"
    Identifier     "layout"
    Screen      0  "intel"
    Inactive       "nvidia"
    Option         "AllowNVIDIAGPUScreens"
EndSection

Section "Device"
    Identifier     "intel"
    Driver         "modesetting"
    BusID          "PCI:0:2:0"  # Verificar com lspci
EndSection

Section "Device"
    Identifier     "nvidia"
    Driver         "nvidia"
    BusID          "PCI:1:0:0"  # Verificar com lspci
EndSection

Section "Screen"
    Identifier     "intel"
    Device         "intel"
EndSection

Section "Screen"
    Identifier     "nvidia"
    Device         "nvidia"
EndSection
EOF
```

### Verificar BusID

```bash
lspci | grep -E "VGA|3D"
# Exemplo:
# 00:02.0 VGA compatible controller: Intel Corporation ...
# 01:00.0 3D controller: NVIDIA Corporation ...

# Converter para formato Xorg: 00:02.0 -> PCI:0:2:0
```

### Script prime-run

```bash
cat > /usr/local/bin/prime-run << 'EOF'
#!/bin/sh
export __NV_PRIME_RENDER_OFFLOAD=1
export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
exec "$@"
EOF

chmod +x /usr/local/bin/prime-run
```

### Uso

```bash
# Aplicação normal (usa iGPU)
firefox

# Aplicação com dGPU NVIDIA
prime-run glxinfo | grep "OpenGL renderer"
prime-run steam
prime-run ./game
```

## PRIME com Wayland/Sway

Para Wayland, o offload funciona diferente:

```bash
# Variáveis para aplicações
export WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1

# No sway config
# exec aplicação (usa iGPU)
# exec env __NV_PRIME_RENDER_OFFLOAD=1 aplicação (usa dGPU)
```

## nvidia-smi e Monitoramento

```bash
# Status da GPU
nvidia-smi

# Monitoramento contínuo
watch -n 1 nvidia-smi

# Verificar se offload está funcionando
# (deve mostrar processo rodando na GPU)
prime-run glxgears &
nvidia-smi
```

## Gerenciamento de Energia

```bash
# Instalar bbswitch (opcional, para desligar GPU completamente)
emerge --ask sys-power/bbswitch

# Configurar
cat > /etc/modprobe.d/bbswitch.conf << 'EOF'
options bbswitch load_state=0 unload_state=1
EOF

# Controle manual
echo ON > /proc/acpi/bbswitch   # Ligar
echo OFF > /proc/acpi/bbswitch  # Desligar
cat /proc/acpi/bbswitch         # Status
```

## CUDA (Desenvolvimento)

```bash
# Instalar CUDA toolkit
echo "dev-util/nvidia-cuda-toolkit NVIDIA-CUDA" >> /etc/portage/package.license/nvidia-cuda-toolkit
emerge --ask dev-util/nvidia-cuda-toolkit

# Testar
nvcc --version
```

## Troubleshooting

### "NVIDIA kernel module not found"
```bash
# Recompilar módulos
emerge --ask @module-rebuild
# ou
emerge --oneshot x11-drivers/nvidia-drivers
```

### Tela preta no boot
- Adicione `nomodeset` aos parâmetros do kernel temporariamente
- Verifique se nouveau está blacklistado
- Verifique versão do driver vs kernel

### Prime-run não funciona
```bash
# Verificar se provider existe
xrandr --listproviders

# Deve mostrar dois providers (Intel e NVIDIA)
```

### Performance baixa
```bash
# Verificar modo de energia
cat /sys/bus/pci/devices/0000:01:00.0/power_state
# Deve ser D0 para ativo

# Forçar performance
nvidia-smi -pm 1
nvidia-smi -pl 80  # Ajustar power limit
```

## Script de Status Completo

```bash
cat > /usr/local/bin/gpu-status << 'EOF'
#!/bin/bash
echo "=== GPU Status ==="
echo ""
echo "Devices:"
lspci | grep -E "VGA|3D"
echo ""
echo "DRI:"
ls -la /dev/dri/
echo ""
echo "NVIDIA:"
nvidia-smi --query-gpu=name,power.draw,temperature.gpu --format=csv 2>/dev/null || echo "GPU desligada ou driver não carregado"
echo ""
echo "Modules:"
lsmod | grep -E "nvidia|nouveau|i915|amdgpu"
EOF

chmod +x /usr/local/bin/gpu-status
```

## Checklist

- [ ] Drivers NVIDIA instalados
- [ ] Nouveau blacklistado
- [ ] Kernel configurado corretamente
- [ ] Módulos carregando no boot
- [ ] Xorg configurado (se usar X11)
- [ ] prime-run funcionando
- [ ] nvidia-smi mostrando GPU
- [ ] Aplicações rodando na dGPU sob demanda
