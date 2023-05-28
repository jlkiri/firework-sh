#!/usr/bin/env bash

set -euo pipefail

# ---------------- BEGIN SETUP ----------------------
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$script_dir"

source vars.sh

rootfs="$rootfs_dir/rootfs.ext4"
kernel_boot_args="init=/lib/systemd/systemd console=ttyS0 reboot=k panic=1 pci=off"
# kernel_boot_args="$kernel_boot_args ip=$vm_ip::$tap_ip:$mask_long::eth0:off"
kernel_boot_args="$kernel_boot_args ip=:::::eth0:dhcp"

tmp_ssh_key_dir="$tmp_vm_dir/ssh"
tmp_mount_target="$tmp_vm_dir/mnt"

function cleanup {
  umount -l "$tmp_mount_target" &> /dev/null || true
}

trap cleanup EXIT

# ---------------- END SETUP ------------------------

function random_string {
  head /dev/urandom | tr -dc a-f0-9 | head -c "$1"
}

vm_id=$(random_string 8)

echo "Starting a Firecracker VM with id $vm_id..."

function setup_ssh {
  ssh-keygen -t ed25519 -C "firecracker" -f "$tmp_ssh_key_dir/$vm_id" -q -N "" <<<y &>/dev/null

  # Copy ssh pub key as authorized_key
  mkdir -p "$tmp_mount_target/root/.ssh"
  cp "$tmp_ssh_key_dir/$vm_id.pub" "$tmp_mount_target/root/.ssh/authorized_keys"

  # Chmod ssh-related files and directories
  chmod 600 "$tmp_mount_target/root/.ssh/authorized_keys"
  chmod 700 "$tmp_mount_target/root/.ssh"
}

function create_tap_dev {
  ip tuntap add dev "$tap_dev" mode tap
  ip link set dev "$tap_dev" up
  ip link set "$tap_dev" master fcbr0

  sysctl -w net.ipv4.conf."$tap_dev".proxy_arp=1 > /dev/null
  sysctl -wq net.ipv4.neigh.default.gc_thresh1=1024
  sysctl -wq net.ipv4.neigh.default.gc_thresh2=2048
  sysctl -wq net.ipv4.neigh.default.gc_thresh3=4096
}

function generate_guest_ipv6_id {
  echo -n "$(random_string 4):$(random_string 4):$(random_string 4):$(random_string 4)"
}

function setup_guest_network {
  mkdir -p $tmp_mount_target/etc/netplan

  # guest_ipv6="fd99::$(generate_guest_ipv6_id)/64"

  cat > "$tmp_mount_target/etc/netplan/config-$vm_id.yaml" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      dhcp6: false
      nameservers:
        addresses:
          - 1.1.1.1
EOF
  # echo -n "$guest_ipv6"
}

tap_dev="fctapvm$vm_id"
vm_mac_addr=$(python3 macgen.py)

mkdir -p $tmp_vm_dir
mkdir -p $socket_dir
mkdir -p $tmp_ssh_key_dir
mkdir -p $tmp_mount_target

socket="$socket_dir/$vm_id.socket"
tmp_rootfs="$tmp_vm_dir/$vm_id.ext4"

cp "$rootfs" "$tmp_rootfs"
echo "DONE: Create a new rootfs for VM based on $rootfs"

{
  umount -l "$tmp_mount_target" &> /dev/null || true
  mount -o loop "$tmp_rootfs" "$tmp_mount_target"
  setup_ssh "$vm_id"
  echo "DONE: Generate SSH keys, id: $vm_id"

  setup_guest_network
  echo "DONE: Setup guest network with netplan"

  umount -l "$tmp_mount_target" &> /dev/null || true
  echo "DONE: Copy additional files to VM rootfs"
}

create_tap_dev
echo "DONE: Created tap device $tap_dev"

# Needed for setup with firewalls
# sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
# sudo iptables -A FORWARD -i $TAP_DEV -o $HOST_IFACE -j ACCEPT

touch "$script_dir/firecracker.log"

cat > "$tmp_vm_dir/config$vm_id.json" <<EOF
{
  "boot-source": {
    "kernel_image_path": "$kernel_path",
    "boot_args": "$kernel_boot_args"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "$tmp_rootfs",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024
  },
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "$vm_mac_addr",
      "host_dev_name": "$tap_dev"
    }
  ],
  "logger": {
    "log_path": "$script_dir/firecracker.log",
    "level": "Debug",
    "show_level": true,
    "show_log_origin": true
  }
}
EOF

firecracker --api-sock "$socket" --config-file "$tmp_vm_dir/config$vm_id.json" > boot.log &
