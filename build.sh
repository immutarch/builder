#!/bin/bash

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

if [ $EUID -ne 0 ]; then
	echo "$(basename $0) must be ran as superuser or sudo"
	exit 1
fi

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
	--flavor)
	BUILD_FLAVOR_MANIFEST="${SCRIPTPATH}/presets/$2.sh"
	BUILD_FLAVOR_MANIFEST_ID="$2"
	POSTCOPY_DIR="$2"
	RELEASETYPE="$2"
	shift
	shift
	;;
	--snapshot_ver)
	SNAPSHOTVERSION="$2"
	shift
	shift
	;;
	--workdir)
	WORKDIR="$2/buildwork"
	shift
	shift
	;;
	--output-dir)
	if [[ -z "$2" ]]; then
		OUTPUT=${WORKDIR}
	else
		OUTPUT="$2"
	fi
	shift
	shift
	;;
    --donotcompress)
	NO_COMPRESS="1"
	shift
	shift
	;;
	*)    # unknown option
    echo "Unknown option: $1"
    exit 1
    ;;
esac
done

# Check if everything is set.
if [[ -z "{$BUILD_FLAVOR_MANIFEST}" ]]; then
	echo "Build flavor was not set. Aborting."
	exit 0
fi
if [[ -z "${SNAPSHOTVERSION}" ]]; then
	echo "Snapshot directory was not set. Aborting."
	exit 0
fi
if [[ -z "${WORKDIR}" ]]; then
	echo "Workdir was not set. Aborting."
	exit 0
fi

source $BUILD_FLAVOR_MANIFEST


ROOT_WORKDIR=${WORKDIR}/rootfs_mnt
echo "Preparing to create deployment image..."
# Pre-build cleanup
umount -l ${ROOT_WORKDIR}
rm -rf ${WORKDIR}/*.img*
rm -rf ${WORKDIR}/*.img
rm -rf ${WORKDIR}/work.img

# Start building here
mkdir -p ${WORKDIR}
mkdir -p ${OUTPUT}
mkdir -p ${ROOT_WORKDIR}
fallocate -l 10000MB ${WORKDIR}/work.img
mkfs.btrfs ${WORKDIR}/work.img
mkdir -p ${WORKDIR}/rootfs_mnt
mount -t btrfs -o loop,compress-force=zstd:1,discard,noatime,nodiratime ${WORKDIR}/work.img ${ROOT_WORKDIR}

echo "(1/6) Bootstrapping main filesystem"
# Start by bootstrapping essentials
mkdir -p ${ROOT_WORKDIR}/${OS_FS_PREFIX}_root/rootfs
mkdir -p ${ROOT_WORKDIR}/var/cache/pacman/pkg
mount --bind /var/cache/pacman/pkg/ ${ROOT_WORKDIR}/var/cache/pacman/pkg
pacstrap ${ROOT_WORKDIR} ${BASE_BOOTSTRAP_PKGS}
echo "(1.5/6) Bootstrapping kernel..."
pacstrap ${ROOT_WORKDIR} ${KERNELCHOICE} ${KERNELCHOICE}-headers

echo "(2/6) Generating fstab..."

# fstab
echo -e ${FSTAB} > ${ROOT_WORKDIR}/etc/fstab

sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' ${ROOT_WORKDIR}/etc/sudoers

echo "(3/6) Bootstrapping core root"
pacstrap -C ${SCRIPTPATH}/pacman.conf ${ROOT_WORKDIR} ${UI_BOOTSTRAP}
echo -e $IMA_RELEASE > ${ROOT_WORKDIR}/etc/ima-release
echo -e $IMAGE_HOSTNAME > ${ROOT_WORKDIR}/etc/hostname
arch-chroot ${ROOT_WORKDIR} systemctl enable ${FLAVOR_CHROOT_SCRIPTS}
echo "(4/6) Copying postcopy items..."
if [[ -d "${SCRIPTPATH}/postcopy_${POSTCOPY_DIR}" ]]; then
	cp -r ${SCRIPTPATH}/postcopy_${POSTCOPY_DIR}/* ${ROOT_WORKDIR}
	rm ${ROOT_WORKDIR}/upstream.sh
	for dirs in ${MKNEWDIR}; do mkdir ${ROOT_WORKDIR}/$dirs; done
# 	if [[ -n "$FLAVOR_PLYMOUTH_THEME" ]]; then
# 		echo "Setting $FLAVOR_PLYMOUTH_THEME theme for plymouth bootsplash..."
# 		arch-chroot ${ROOT_WORKDIR} plymouth-set-default-theme -R $FLAVOR_PLYMOUTH_THEME
# 	fi
# 	for binary in ${POSTCOPY_BIN_EXECUTION}; do arch-chroot ${ROOT_WORKDIR} $binary && rm -rf ${ROOT_WORKDIR}/usr/bin/$binary; done
	echo -e "${PACMAN_ONLOAD}" > ${ROOT_WORKDIR}/usr/lib/systemd/system/var-lib-pacman.mount
	arch-chroot ${ROOT_WORKDIR} systemctl enable ${FLAVOR_CHROOT_SCRIPTS}
	echo "(4.5/6) Generating en_US.UTF-8 locale..."
	sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' ${ROOT_WORKDIR}/etc/locale.gen
	arch-chroot ${ROOT_WORKDIR} locale-gen
	echo "LANG=\"en_US.UTF-8\"" > ${ROOT_WORKDIR}/etc/locale.conf
	arch-chroot ${ROOT_WORKDIR} mkinitcpio -P
fi

echo "(5/6) Stop doing things in container..."
# Cleanup
umount -l ${ROOT_WORKDIR}/var/cache/pacman/pkg/

# Finish for now
echo "(6/6) Packaging snapshot..."
btrfs subvolume snapshot -r ${ROOT_WORKDIR} ${ROOT_WORKDIR}/${OS_FS_PREFIX}_root/rootfs/${FLAVOR_BUILDVER}
btrfs send -f ${OUTPUT}/${FLAVOR_FINAL_DISTRIB_IMAGE}.img ${ROOT_WORKDIR}/${OS_FS_PREFIX}_root/rootfs/${FLAVOR_BUILDVER}
umount -l ${ROOT_WORKDIR} && umount -l ${WORKDIR}/work.img && rm -rf ${WORKDIR} && ${WORKDIR}/work.img
if [[ -z "${NO_COMPRESS}" ]]; then
	echo "Compressing image..."
	zstd --ultra -z ${OUTPUT}/${FLAVOR_FINAL_DISTRIB_IMAGE}.img -o ${OUTPUT}/${FLAVOR_FINAL_DISTRIB_IMAGE}.img.zst
	rm -rf ${OUTPUT}/${FLAVOR_FINAL_DISTRIB_IMAGE}.img
	chown 1000:1000 ${OUTPUT}/${FLAVOR_FINAL_DISTRIB_IMAGE}.img.zst
	chmod 777 ${OUTPUT}/${FLAVOR_FINAL_DISTRIB_IMAGE}.img.zst
fi

echo "Build complete."
