#! /bin/bash
# SPDX-License-Identifier: BSD-2-Clause

sed -i -e 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' "$TARGET_DIR"/etc/ssh/sshd_config
sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' "$TARGET_DIR"/etc/ssh/sshd_config
