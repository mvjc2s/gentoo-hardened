# 04 - Custom Initramfs

## Visão Geral

O initramfs é responsável por:
1. Aguardar USB com secrets
2. Abrir keyfile criptografado
3. Abrir partição LUKS com detached header
4. Montar btrfs com subvolumes
5. Transferir controle para o sistema

## Estrutura

```
/usr/src/initramfs/
├── bin/
│   └── busybox          # Shell e utilitários
├── sbin/
│   ├── cryptsetup       # Gerenciamento LUKS (estático)
│   ├── btrfs            # Ferramentas btrfs (estático)
│   ├── blkid            # Identificação de dispositivos
│   └── mdev -> busybox  # Hotplug simplificado
├── dev/
│   ├── console
│   ├── null
│   ├── nvme0n1*         # Dispositivos NVMe
│   └── mapper/
│       └── control
├── etc/
│   └── mdev.conf        # Configuração hotplug
├── mnt/
│   └── usb/             # Ponto de montagem USB
├── newroot/             # Ponto de montagem do sistema
├── proc/
├── sys/
└── init                 # Script principal
```

## Preparação dos Binários Estáticos

```bash
# Verificar se cryptsetup é estático
file /sbin/cryptsetup
# Deve mostrar "statically linked"

# Se não for estático, recompilar
echo "sys-fs/cryptsetup static static-libs" >> /etc/portage/package.use/cryptsetup
emerge --ask --oneshot sys-fs/cryptsetup

# Verificar busybox
file /bin/busybox

# Verificar btrfs
file /sbin/btrfs.static
# Se não existir:
echo "sys-fs/btrfs-progs static-libs" >> /etc/portage/package.use/btrfs-progs
emerge --ask --oneshot sys-fs/btrfs-progs
```

## Usando o Script de Build

O repositório inclui um script de build automatizado:

```bash
cd /path/to/gentoo-lenovo-loq/initramfs

# Revisar e editar o script init
vim init

# Configurar PARTUUID do disco criptografado
# Obter com: blkid -s PARTUUID -o value /dev/nvme0n1p2

# Executar build
chmod +x build.sh
./build.sh
```

## Build Manual (alternativa)

```bash
# Criar estrutura
mkdir -p /usr/src/initramfs/{bin,sbin,etc,dev,dev/disk/{by-label,by-uuid,by-partuuid},dev/mapper,lib,lib64,mnt,mnt/usb,newroot,proc,sys,run,tmp}

# Permissões especiais
chmod 0555 /usr/src/initramfs/{proc,sys}
chmod 1777 /usr/src/initramfs/tmp

# Copiar binários
cp /bin/busybox /usr/src/initramfs/bin/
cp /sbin/cryptsetup /usr/src/initramfs/sbin/  # ou cryptsetup.static
cp /sbin/btrfs.static /usr/src/initramfs/sbin/btrfs

# Links simbólicos do busybox
cd /usr/src/initramfs/bin
for cmd in sh mount umount mkdir cat echo ls sleep printf clear readlink; do
    ln -sf busybox $cmd
done
cd /usr/src/initramfs/sbin
for cmd in switch_root setsid mdev; do
    ln -sf ../bin/busybox $cmd
done

# Device nodes
cd /usr/src/initramfs/dev
mknod -m 600 console c 5 1
mknod -m 666 null c 1 3
mknod -m 666 zero c 1 5
mknod -m 666 tty c 5 0
mknod -m 620 tty0 c 4 0
mknod -m 444 urandom c 1 9
mknod -m 444 random c 1 8
mknod -m 660 mapper/control c 10 236

# NVMe nodes
mknod -m 660 nvme0n1 b 259 0
mknod -m 660 nvme0n1p1 b 259 1
mknod -m 660 nvme0n1p2 b 259 2

# Copiar init
cp /path/to/init /usr/src/initramfs/init
chmod 755 /usr/src/initramfs/init
```

## Configurando o Script Init

Edite `/usr/src/initramfs/init` e ajuste:

```bash
# Label do USB com secrets
USB_LABEL="INTFS_KEY"

# PARTUUID do disco criptografado
# Obter com: blkid -s PARTUUID -o value /dev/nvme0n1p2
CRYPT_DISK_PARTUUID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Nome do dispositivo mapeado
CRYPT_NAME="gentoo"

# Subvolumes btrfs
BTRFS_SUBVOLS="@root:root @home:home @usr:usr @var:var @opt:opt"

# Timeouts
USB_TIMEOUT=30
MAX_TRIES=3
```

## Testando o Initramfs

Antes de recompilar o kernel, você pode testar com QEMU (limitado):

```bash
# Criar imagem cpio para teste
cd /usr/src/initramfs
find . | cpio -o -H newc | gzip > /tmp/initramfs.cpio.gz

# Testar com QEMU (não vai funcionar completamente sem o hardware real)
# mas pode verificar erros de sintaxe no init
qemu-system-x86_64 -kernel /boot/vmlinuz -initrd /tmp/initramfs.cpio.gz -append "console=ttyS0" -nographic
```

## Usando initramfs.list (alternativa)

Em vez de apontar para um diretório, você pode usar um arquivo de especificação:

```bash
# No kernel config:
# CONFIG_INITRAMFS_SOURCE="/usr/src/initramfs/initramfs.list"

# O arquivo initramfs.list especifica cada arquivo individualmente
# Veja initramfs/initramfs.list neste repositório
```

## Troubleshooting

### Erro "not a valid ELF"
Binário não é estático ou incompatível. Verifique com `file`.

### Erro "cryptsetup: not found"
Link simbólico não criado ou PATH incorreto no init.

### USB não detectado
- Verifique se USB mass storage está no kernel
- Verifique device nodes para USB (sd*)
- Aumente USB_TIMEOUT

### "No such file or directory" no switch_root
- Verifique se /newroot está montado
- Verifique se /sbin/init existe no sistema montado

### Kernel panic após switch_root
- Verifique se todos os subvolumes necessários estão montados
- Verifique se /usr está acessível se usar /usr separado

## Debugging

Adicione no init para debug:

```bash
# No início do init
set -x  # Mostra cada comando executado

# Antes do switch_root
echo "Pressione Enter para continuar..."
read dummy

# Ou adicione shell de emergência
exec sh
```

## Checklist

- [ ] Binários estáticos verificados
- [ ] Estrutura de diretórios criada
- [ ] Device nodes criados (incluindo NVMe)
- [ ] Links simbólicos do busybox
- [ ] Script init configurado com PARTUUID correto
- [ ] USB label configurada
- [ ] mdev.conf instalado
- [ ] Kernel apontando para /usr/src/initramfs
- [ ] Kernel recompilado com initramfs
