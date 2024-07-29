#!/bin/bash
rm -rf /tmp/builder-releasetag
rm -rf /tmp/build_temp_ver
export DISTRO_NAME="Immutarch"
export OS_CODENAME="Beta"
export OS_FS_PREFIX="ima"
export RELEASETAG=$(date +%s)
echo -e ${RELEASETAG} > /tmp/builder-releasetag
echo -e "$(echo ${DISTRO_NAME} | tr '[:upper:]' '[:lower:]')_$(date +%Y%m%d%H%M)_$(echo ${OS_CODENAME} | tr '[:upper:]' '[:lower:]')_${RELEASETAG}" > /tmp/build_temp_ver
export FLAVOR_BUILDVER=$(cat /tmp/build_temp_ver)
export IMAGEFILE="${FLAVOR_BUILDVER}"
export FLAVOR_CHROOT_SCRIPTS="sddm bluetooth sshd ima-oobe-prerun nix-daemon systemd-timesyncd NetworkManager ima-offload.target var-lib-pacman.mount nix.mount opt.mount root.mount srv.mount usr-lib-debug.mount usr-local.mount var-cache-pacman.mount var-lib-docker.mount var-lib-flatpak.mount var-lib-systemd-coredump.mount var-log.mount var-tmp.mount"
#export FLAVOR_PLYMOUTH_THEME="steamos"
export FLAVOR_FINAL_DISTRIB_IMAGE=$FLAVOR_BUILDVER
export KERNELCHOICE="linux-lts"
export BASE_BOOTSTRAP_PKGS="base base-devel flatpak gsettings-system-schemas arch-install-scripts linux-firmware amd-ucode intel-ucode sddm dkms jq btrfs-progs grub efibootmgr openssh"
export UI_BOOTSTRAP="plasma plasma-nm dolphin konsole kate sddm mesa vulkan-radeon vulkan-intel nix spectacle gwenview xf86-video-intel feh xorg-xinit python-pyqt5"
export IMA_RELEASE="IMAGE_ID=\"${FLAVOR_BUILDVER}\"\nOS_TAG=${RELEASETAG}\nRELEASETYPE=$(echo ${OS_CODENAME} | tr '[:upper:]' '[:lower:]')\nISINTERNAL=no"
export PACMAN_ONLOAD="[Unit]\nDescription=${DISTRO_NAME} onload - /var/lib/pacman\n\n[Mount]\nWhat=/${OS_FS_PREFIX}_root/rootfs/${FLAVOR_FINAL_DISTRIB_IMAGE}/var/lib/pacman\nWhere=/var/lib/pacman\nType=none\nOptions=bind\n\n[Install]\nWantedBy=ima-offload.target"
export MKNEWDIR="nix boot/efi"
export FSTAB="\nLABEL=${OS_FS_PREFIX}_root /          btrfs subvol=rootfs/${FLAVOR_BUILDVER},compress-force=zstd:1,discard,noatime,nodiratime 0 0\nLABEL=${OS_FS_PREFIX}_root /${OS_FS_PREFIX}_root btrfs rw,compress-force=zstd:1,discard,noatime,nodiratime,nodatacow 0 0\nLABEL=${OS_FS_PREFIX}_var /var       ext4 rw,relatime 0 0\nLABEL=${OS_FS_PREFIX}_home /home      ext4 rw,relatime 0 0\n"
export IMAGE_HOSTNAME="grasshopper"
#export POSTCOPY_BIN_EXECUTION="setuphandycon add_additional_pkgs"
