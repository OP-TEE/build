#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2014, Linaro Limited
# Copyright (c) 2021, Huawei Technologies Co., Ltd
#

import argparse
import os
import select
import socket
import sys
import termios

handle_telnet = False
cmd_bytes = bytearray()

TELNET_IAC = 0xff
TELNET_DO = 0xfd
TELNET_WILL = 0xfb
TELNET_SUPRESS_GO_AHEAD = 0x1


def get_args():

    parser = argparse.ArgumentParser(description='Starts a TCP server to be '
                                     'used as a terminal (for QEMU or FVP). '
                                     'When the server receives a connection '
                                     'it puts the terminal in raw mode so '
                                     'that control characters (Ctrl-C etc.) '
                                     'are interpreted remotely. Only when the '
                                     'peer has closed the connection the '
                                     'terminal settings are restored.')
    parser.add_argument('port', nargs=1, type=int,
                        help='local TCP port to listen on')
    parser.add_argument('-t', '--telnet', action='store_true',
                        help='handle telnet commands (FVP)')
    return parser.parse_args()


def set_stty_noncanonical():

    t = termios.tcgetattr(sys.stdin.fileno())
    # iflag
    t[0] = t[0] & ~termios.ICRNL
    # lflag
    t[3] = t[3] & ~(termios.ICANON | termios.ECHO | termios.ISIG)
    t[6][termios.VMIN] = 1   # Character-at-a-time input
    t[6][termios.VTIME] = 0  # with blocking
    termios.tcsetattr(sys.stdin.fileno(), termios.TCSAFLUSH, t)


def handle_telnet_codes(fd, buf):

    global handle_telnet
    global cmd_bytes

    if (not handle_telnet):
        return

    if (fd == -1):
        cmd_bytes.clear()
        return

    # Iterate on a copy because buf is modified in the loop
    for c in bytearray(buf):
        if (len(cmd_bytes) or c == TELNET_IAC):
            cmd_bytes.append(c)
            del buf[0]
        if (len(cmd_bytes) == 3):
            if (cmd_bytes[1] == TELNET_DO):
                cmd_bytes[1] = TELNET_WILL
            elif (cmd_bytes[1] == TELNET_WILL):
                if (cmd_bytes[2] == TELNET_SUPRESS_GO_AHEAD):
                    # We're done after responding to this
                    handle_telnet = False
                cmd_bytes[1] = TELNET_DO
            else:
                # Unknown command, ignore it
                cmd_bytes.clear()
            if (len(cmd_bytes)):
                os.write(fd, cmd_bytes)
                cmd_bytes.clear()


def serve_conn(conn):

    fd = conn.fileno()
    poll = select.poll()
    poll.register(sys.stdin.fileno(), select.POLLIN)
    poll.register(fd, select.POLLIN)
    while (True):
        for readyfd, _ in poll.poll():
            try:
                data = os.read(readyfd, 512)
                if (len(data) == 0):
                    print('soc_term: read fd EOF')
                    return
                buf = bytearray(data)
                handle_telnet_codes(readyfd, buf)
                if (readyfd == fd):
                    to = sys.stdout.fileno()
                else:
                    to = fd
            except ConnectionResetError:
                print('soc_term: connection reset')
                return
            try:
                # Python >= 3.5 handles EINTR internally so no loop required
                os.write(to, buf)
            except WriteErrorException:
                print('soc_term: write error')
                return


def main():

    global handle_telnet
    args = get_args()
    port = args.port[0]
    sock = socket.socket()
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(('127.0.0.1', port))
    sock.listen(5)
    print(f'listening on port {port}')
    if (args.telnet):
        print('Handling telnet commands')
    old_term = termios.tcgetattr(sys.stdin.fileno())
    while True:
        try:
            conn, _ = sock.accept()
            print(f'soc_term: accepted fd {conn.fileno()}')
            handle_telnet = args.telnet
            handle_telnet_codes(-1, bytearray())  # Reset internal state
            set_stty_noncanonical()
            serve_conn(conn)
            conn.close()
        except KeyboardInterrupt:
            return
        finally:
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSAFLUSH, old_term)


if __name__ == "__main__":
    main()
