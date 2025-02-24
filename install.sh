#!/bin/bash
# Build a Linux kernel, install it on THIS machine, and reboot the machine.
# This script is only known to work for Debian/Ubuntu-based machines.

set -e
LOCALVERSION=GCE+ORACLE
GCE_PKG_DIR=${PWD}/gce/${LOCALVERSION}/pkg
GCE_INSTALL_DIR=${PWD}/gce/${LOCALVERSION}/install
GCE_BUILD_DIR=${PWD}/gce/${LOCALVERSION}/build
KERNEL_PKG=kernel-${LOCALVERSION}.tar.gz2
MAKE_OPTS="-j$(nproc) \
           LOCALVERSION=${LOCALVERSION} \
           EXTRAVERSION="" \
           INSTALL_PATH=${GCE_INSTALL_DIR}/boot \
           INSTALL_MOD_PATH=${GCE_INSTALL_DIR} \
           INSTALL_MOD_STRIP=1"

echo "Cleaning up directories..."
mkdir -p "${GCE_BUILD_DIR}"
mkdir -p "${GCE_INSTALL_DIR}/boot"
mkdir -p "${GCE_PKG_DIR}"

set +e
if [ ! -f .config ]; then
    echo "Copying /boot config to .config..."
    cp "/boot/config-$(uname -r)" . || { echo "Failed to copy /boot/config-$(uname -r)"; exit 1; }
    cp "config-$(uname -r)" .config
else
    echo ".config already exists, skipping copy."
fi

echo "Merging custom configuration..."
scripts/kconfig/merge_config.sh -m config.gce "config-$(uname -r)" > /tmp/make.merge_config

echo "Disabling security keys..."
scripts/config --disable SYSTEM_REVOCATION_KEYS
scripts/config --disable SYSTEM_TRUSTED_KEYS

echo "Running make olddefconfig..."
make olddefconfig > /tmp/make.olddefconfig

echo "Preparing kernel build..."
make ${MAKE_OPTS} prepare > /tmp/make.prepare

echo "Building kernel..."
make ${MAKE_OPTS} > /tmp/make.default

echo "Building kernel modules..."
make ${MAKE_OPTS} modules > /tmp/make.modules

echo "Installing kernel..."
make ${MAKE_OPTS} install > /tmp/make.install

echo "Installing modules..."
make ${MAKE_OPTS} modules_install > /tmp/make.modules_install
set -e

echo "Creating kernel tarball..."
(cd "${GCE_INSTALL_DIR}" && tar -cvzf "${GCE_PKG_DIR}/${KERNEL_PKG}" boot/* lib/modules/* --owner=0 --group=0 > /tmp/make.tarball)

echo "Using tarball ${GCE_PKG_DIR}/${KERNEL_PKG} for local installation"

# Remove old GCE-related kernel files
sudo rm -rf /boot/*GCE /lib/modules/*GCE

echo "Extracting kernel tarball..."
sudo tar --no-same-owner -xzvf "${GCE_PKG_DIR}/${KERNEL_PKG}" -C / > /tmp/tar.out.txt

echo "Regenerating initramfs images..."
cd /boot
for v in $(ls vmlinuz-* | sed 's/vmlinuz-//g'); do
    sudo mkinitramfs -k -o "initrd.img-${v}" "${v}"
done

echo "Updating GRUB..."
sudo update-grub

# echo "Rebooting machine..."
# sudo reboot
