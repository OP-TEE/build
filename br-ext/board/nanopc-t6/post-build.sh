#! /bin/bash
# SPDX-License-Identifier: BSD-2-Clause

# Update SSH configuration to allow root login and empty passwords
sed -i -e 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' "$TARGET_DIR"/etc/ssh/sshd_config
sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' "$TARGET_DIR"/etc/ssh/sshd_config

# Configure enP2p33s0 with DHCP
cat <<EOT > "$TARGET_DIR"/etc/network/interfaces
auto enP2p33s0
iface enP2p33s0 inet dhcp
EOT

# Check if /etc/resolv.conf is a symlink and remove it
if [ -L "$TARGET_DIR/etc/resolv.conf" ]; then
    echo "Removing symlink for /etc/resolv.conf"
    rm "$TARGET_DIR/etc/resolv.conf"
fi

# Create a new static resolv.conf with desired nameservers
cat <<EOT > "$TARGET_DIR/etc/resolv.conf"
nameserver 1.1.1.1
EOT
