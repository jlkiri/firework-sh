#!/usr/bin/env bash

set -euo pipefail

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $script_dir

source vars.sh

mount_dir="$script_dir/rootfs"
rootfs="$rootfs_dir/rootfs.ext4"
base_rootfs="$downloads_dir/rootfs.tar.xz"

rm -rf "$rootfs" || true

function cleanup {
    # Unmount the disk image and remove the temporary mount directory   
    {
        umount --lazy "$mount_dir" &> /dev/null || true
        rm -rf "$mount_dir"
    } || true
}

cleanup
trap cleanup EXIT

mkdir -p "$rootfs_dir"

# Create an empty file
echo "Allocating an empty 4GB file..."
truncate -s 4G "$rootfs"

# Create an ext4 filesystem on the file
echo "Creating an ext4 filesystem on the file..."
mkfs.ext4 "$rootfs" &> /dev/null

mkdir -p $mount_dir
mount -o loop "$rootfs" $mount_dir

echo "Unpacking the base rootfs image to the mount dir..."
tar -xf "$base_rootfs" -C "$mount_dir"

echo "Pre-installing programs in the base rootfs image with Docker..."

img_id=$(docker build . -t rootfs)
container_id=$(docker run --rm --tty --detach rootfs /bin/bash)

echo "Copying the contents of the container back to the rootfs..."
docker cp $container_id:/ $mount_dir

echo "Done."
