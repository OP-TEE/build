# OP-TEE on HiKey960

# Contents
1. [Introduction](#1-introduction)
2. [Supported HiKey960 boards?](#2-supported-hikey960-boards)
3. [UART adapter board](#3-uart-adapter-board)
4. [Regular build](#4-regular-build)
5. [External guide](#5-external-guide)
6. [Recovery](#6-recovery)

# 1. Introduction
The instructions here will tell how to run OP-TEE on HiKey960.

# 2. Supported HiKey960 boards?
There are two different versions of the HiKey960 board.

| Name | Manufacturer | Memory | Flash | Comment |
|------|--------------|--------|-------|---------|
| HiKey960 | Archermind/LeMaker | 3GB | 32GB | v2 uses DIP Switches (SW2201) |
| HiKey960 | Archermind/LeMaker | 3GB | 32GB | v1 uses Jumpers (J2001) |

# 3. UART adapter board
Everything is configured to use the [96Boards UART Adapter Board]. The UART is
by default configured to UART6. If you have a v1 board and need to use UART5,
then you need to change that before building. See `CFG_CONSOLE_UART` in
[hikey960.mk].

# 4. Regular build
Just follow the "Get and build the solution" in the [README.md] file. If
`make flash` doesn't work, try `make recovery`.

# 5. External guide
https://github.com/ARM-software/arm-trusted-firmware/blob/master/docs/plat/hikey960.rst

# 6. Recovery
If you manage to corrupt the device, so that fastboot doesn't load automatically
on boot, then you will need to run the recovery procedure. Basically what you
will need to do is use another make target and change some jumpers. All that is
described when you run the target:
```bash
$ make recovery
```

[README.md]: ../README.md
[hikey960.mk]: https://github.com/OP-TEE/build/blob/master/hikey960.mk
[96Boards UART Adapter Board]: http://www.96boards.org/product/uarts
