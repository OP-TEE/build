#!/usr/bin/env python
# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2018, Linaro Limited

import argparse
import shutil
import os
import re

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--br', required=True,
                        help='Path to buildroot tree')
    parser.add_argument('--out', required=True,
                        help='Path to buildroot out directory')
    parser.add_argument('--top-dir', required=True,
                        help='Replaces %TOP_DIR% in defconfig files')
    parser.add_argument('--br-ext-optee', required=True,
                        help='Path the OP-TEE external buildroot tree')
    parser.add_argument('--br-defconfig', required=True, action='append',
                        help='Buildroot defconfig file')
    parser.add_argument('--make-cmd', required=True,
                        help='Make command')
    return parser.parse_args()

def concatenate_files(top_dir, dst, srcs):
    with open(dst, 'w') as outfile:
        for fname in srcs:
            with open(fname) as infile:
                for line in infile:
                    outfile.write(line.replace('%TOP_DIR%', top_dir))

def main():
    args = get_args()

    if not os.path.isdir(args.out):
        os.makedirs(args.out)

    concatenate_files(args.top_dir, args.out + '/defconfig', args.br_defconfig)

    if os.path.isabs(args.out):
        out = args.out
    else:
        out = '../' + args.out

    if os.path.isabs(args.br_ext_optee):
        br_ext_optee = args.br_ext_optee
    else:
        br_ext_optee = '../' + args.br_ext_optee

    os.execlp(args.make_cmd, args.make_cmd, '-C', args.br, 'O=' + out,
              'BR2_EXTERNAL=' + br_ext_optee,
              'BR2_DEFCONFIG=' + out + '/defconfig', 'defconfig')

if __name__ == "__main__":
    main()
