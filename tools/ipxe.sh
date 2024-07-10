#!/bin/bash
# https://github.com/MiddelkoopT/ohpc-jetstream2/blob/main/ipxe.sh
set -e

ARCH=x86_64
DISK=disk.img
PART="${DISK}-1"
IPXE=bin-${ARCH}-efi/ipxe.efi
SIZE=2  # GPT+ takes 1M (2048 512 byte blocks) on both ends

## Build iPXE (note git tag hack)
echo '--- build ipxe'
if [[ ! -d ipxe ]] ; then 
  git clone --depth 1 https://github.com/ipxe/ipxe.git
  ( cd ipxe ; git tag v1.99.0 )
fi

( cd ipxe/src && make ${IPXE} EMBED=../../boot.ipxe )

echo '--- build partition'
dd if=/dev/zero of=${DISK}-1 bs=1M count=${SIZE} conv=sparse

mformat -i ${PART} ::

mmd -i ${PART} ::/EFI
mmd -i ${PART} ::/EFI/BOOT
mcopy -i ${PART} ipxe/src/${IPXE} ::/EFI/BOOT/BOOTX64.EFI
mcopy -i ${PART} startup.nsh ::/EFI/BOOT/STARTUP.NSH

mdir -i ${PART} ::/EFI/BOOT

echo '--- build disk'
dd if=/dev/zero of=${DISK} bs=1M count=$(( ${SIZE} + 2 )) conv=sparse
## EFI is at offset 1M (2048*512)
sfdisk ${DISK} <<EOF
label: gpt
unit: sectors
first-lba: 2048
start=2048, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=EFI, size=$(( ${SIZE} * 2048 ))
EOF

echo '--- load partition'
dd if=${PART} of=${DISK} bs=1M seek=1 count=${SIZE} conv=sparse conv=notrunc

echo '--- check'
mdir -i ${DISK}@@1M ::/EFI/BOOT

