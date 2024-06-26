#!/bin/sh

# Copyright MeemeeLab 2024
# SPDX-License-Identifier: GPL-2.0-or-later

EXTERNAL_REPO="https://github.com/MeemeeLab/CoreMP135_buildroot-external-st.git"
BUILDROOT_REPO="https://github.com/buildroot/buildroot.git"
PKGBUILD_KERNEL_REPO="https://github.com/MeemeeLab/PKGBUILD-linux-m5stackcoremp135.git"
ALARM_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz"

checking() {
    echo
    echo "[CHECK ] $1"
    echo
}
running() {
    echo
    echo "[ WAIT ] $1"
    echo
}
skipped() {
    echo
    echo "[ SKIP ] $1"
    echo
}
ok() {
    echo
    echo "[  OK  ] $1"
    echo
}
info() {
    echo "[ INFO ] $1"
}

check_environment() {
    checking "Environment"

    if [ ! -x "$(command -v pacman)" ]; then
        info "Installation of pacman cannot be found; Build cannot continue"
        return 1
    fi

    if [ ! -x "$(command -v mkimage)" ]; then
        info "Installation of mkimage cannot be found; Did you install uboot-tools?"
        return 1
    fi

    if [ ! -x "$(command -v qemu-arm-static)" ]; then
        info "Installation of qemu-arm-static cannot be found; Did you install qemu-user-static?"
        return 1
    fi

    ok "Environment"
}

prepare_dir() {
    running "Prepare directory"

    if [ -d "build" ]; then
        return
    fi

    ok "Prepare directory"
    mkdir build
}

prepare_makepkg() {
    pushd build
    running "Prepare makepkg.conf"

    cp /etc/makepkg.conf .

    sed -e '/^CHOST/s/^/#/' -i makepkg.conf
    sed -e '/^CARCH/s/^/#/' -i makepkg.conf

    printf "\nCARCH=\"armv7h\"" >> makepkg.conf
    printf "\nCHOST=\"arm-buildroot-linux-gnueabihf\"" >> makepkg.conf

    ok "Prepare makepkg.conf"
    popd
}

external_repo() {
    pushd build
    running "Setup external"

    if [ -d "external" ]; then
        pushd external

        git pull

        ok "Setup external"
        popd
        popd
        return
    fi

    git clone $EXTERNAL_REPO external

    ok "Setup external"
    popd
}

buildroot_repo() {
    pushd build
    running "Setup buildroot"

    if [ ! -d "buildroot" ]; then
        git clone $BUILDROOT_REPO buildroot
    else
        pushd buildroot
        git pull
        popd
    fi

    # We may have update on external repo, so always defconfig
    # despite existence of .config
    pushd buildroot
    make BR2_EXTERNAL=../external/ m5stack_coremp135_defconfig
    popd

    ok "Setup buildroot"
    popd
}

pkgbuild_kernel_repo() {
    pushd build
    running "Setup kernel PKGBUILD"

    if [ -d "PKGBUILD-linux-m5stackcoremp135" ]; then
        pushd PKGBUILD-linux-m5stackcoremp135

        git pull

        ok "Setup external"
        popd
        popd
        return
    fi

    git clone $PKGBUILD_KERNEL_REPO PKGBUILD-linux-m5stackcoremp135

    ok "Setup kernel PKGBUILD"
    popd
}

download_alarm() {
    pushd build
    running "Download ALARM"

    if [ -f "alarm.tar.gz" ]; then
        skipped "Download ALARM"
        popd
        return
    fi

    wget -O alarm.tar.gz $ALARM_URL

    ok "Download ALARM"
    popd
}

tfa() {
    pushd build/buildroot
    running "Build TF-A"

    make -j$(nproc) arm-trusted-firmware

    ok "Build TF-A"
    popd
}

genimage() {
    pushd build/buildroot
    running "Build genimage"

    make -j$(nproc) host-genimage

    export PATH="$(pwd)/output/host/bin/:$PATH"
    
    ok "Build genimage"
    popd
}

pkgbuild_kernel() {
    pushd build/PKGBUILD-linux-m5stackcoremp135
    running "Kernel PKGBUILD"

    # Just recompile, because it may have an update
    rm -rf pkg src
    makepkg --config ../makepkg.conf -f

    ok "Kernel PKGBUILD"
    popd
}

generate_image() {
    pushd build
    running "Generate image"

    cp buildroot/output/images/tf-a-stm32mp135f-coremp135.stm32 .
    cp buildroot/output/images/fip.bin .

    if [ -f "sdcard.img" ]; then
        rm sdcard.img
    fi

    BUILD_DIR=. sh buildroot/support/scripts/genimage.sh -c ../configs/genimage.cfg

    ok "Generate image"
    popd
}

prepare_rootfs() {
    pushd build
    running "Prepare rootfs"

    local ROOTFS_OFFSET=$(($(fdisk -l sdcard.img | sed -n "s:^sdcard.img5 *\([0-9]*\) .*$:\1:p") * 512))

    info "rootfs offset: $ROOTFS_OFFSET"

    info "Creating rootfs may require sudo privileges. Press any key to continue..."
    read -n1 -r

    if [ -d "rootfs" ]; then
        sudo umount rootfs || true
        rmdir rootfs
    fi

    local LOOPBACK_DEV=$(sudo losetup -o $ROOTFS_OFFSET --show -f sdcard.img)

    info "loopback device allocated: $LOOPBACK_DEV"

    sudo mkfs.ext4 $LOOPBACK_DEV

    mkdir rootfs
    sudo mount -o loop $LOOPBACK_DEV rootfs

    sudo bsdtar -xpf alarm.tar.gz -C rootfs

    sudo cp ./rootfs/boot/initramfs-linux.img ./rootfs/boot/initramfs-linux.img.bak

    sudo pacman --noconfirm --sysroot ./rootfs/ -R linux-armv7
    sudo pacman --noconfirm --sysroot ./rootfs/ -U ./PKGBUILD-linux-m5stackcoremp135/*.pkg.tar.zst

    sudo mv ./rootfs/boot/initramfs-linux.img.bak ./rootfs/boot/initramfs-linux.img

    sudo cp ../configs/boot.txt ./rootfs/boot/
    sudo mkimage -A arm -O linux -T script -C none -n "U-Boot boot script" -d ./rootfs/boot/boot.txt ./rootfs/boot/boot.scr

    sync

    sudo umount rootfs
    rmdir rootfs

    sudo losetup -d $LOOPBACK_DEV

    ok "Prepare rootfs"
    popd
}

generate_oob() {
    pushd build
    running "Create OOB image"

    cp sdcard.img sdcard_oob.img

    local ROOTFS_OFFSET=$(($(fdisk -l sdcard_oob.img | sed -n "s:^sdcard_oob.img5 *\([0-9]*\) .*$:\1:p") * 512))

    info "rootfs offset: $ROOTFS_OFFSET"

    if [ -d "rootfs" ]; then
        sudo umount rootfs || true
        rmdir rootfs
    fi

    local LOOPBACK_DEV=$(sudo losetup -o $ROOTFS_OFFSET --show -f sdcard_oob.img)

    info "loopback device allocated: $LOOPBACK_DEV"

    mkdir rootfs
    sudo mount -o loop $LOOPBACK_DEV rootfs

    info "Package auto resize"
    cp -r ../configs/PKGBUILD-m5stack-resize-rootfs .

    pushd PKGBUILD-m5stack-resize-rootfs
    rm -rf *.pkg.tar.zst
    makepkg
    popd

    info "Update system"
    if [ ! -d "/tmp/coremp135-arch" ]; then
        sudo mkdir /tmp/coremp135-arch
    fi
    sudo mount --bind /tmp/coremp135-arch ./rootfs/var/cache/pacman/pkg/

    sudo tee ./rootfs/setup.sh << EOF
pacman-key --init
pacman-key --populate
pacman --noconfirm -Syu sudo
EOF

    sudo cp "$(which qemu-arm-static)" ./rootfs/usr/bin/
    sudo arch-chroot ./rootfs/ qemu-arm-static /bin/bash /setup.sh
    sudo rm ./rootfs/setup.sh

    info "Configure system"
    sudo cp ../configs/sudoers ./rootfs/etc/sudoers
    sudo chmod 440 ./rootfs/etc/sudoers
    sudo chown root:root ./rootfs/etc/sudoers
    sudo cp ../configs/mkinitcpio.conf ./rootfs/etc/mkinitcpio.conf
    sudo chmod 644 ./rootfs/etc/mkinitcpio.conf
    sudo chown root:root ./rootfs/etc/mkinitcpio.conf

    sudo tee ./rootfs/configure.sh << EOF
groupadd sudo
usermod -aG sudo alarm
mkinitcpio -P
ln -s /etc/systemd/system/resize-rootfs.service /etc/systemd/system/multi-user.target.wants/resize-rootfs.service
EOF
    sudo arch-chroot ./rootfs/ qemu-arm-static /bin/bash /configure.sh
    sudo rm ./rootfs/configure.sh

    info "Install auto resize"
    sudo pacman --noconfirm --sysroot ./rootfs/ -U ./PKGBUILD-m5stack-resize-rootfs/*.pkg.tar.zst

    sudo rm ./rootfs/usr/bin/qemu-arm-static
    sudo umount ./rootfs/var/cache/pacman/pkg/
    sudo rm -rf /tmp/coremp135-arch

    sync

    sudo umount rootfs
    rmdir rootfs

    sudo losetup -d $LOOPBACK_DEV

    ok "Create OOB image"
    popd
}


main() {
    set -e

    check_environment

    prepare_dir
    prepare_makepkg
    external_repo
    buildroot_repo
    pkgbuild_kernel_repo
    download_alarm
    tfa
    genimage
    pkgbuild_kernel
    generate_image
    prepare_rootfs
    generate_oob

    if [ -f "sdcard.img" ]; then
        rm sdcard.img
    fi
    if [ -f "sdcard_oob.img" ]; then
        rm sdcard_oob.img
    fi

	mv build/sdcard.img .
	mv build/sdcard_oob.img .

    ok "Build complete"

    info "Writable image available at sdcard.img"
    info "Make sure to populate keys and upgrade after booting!"
}

main
