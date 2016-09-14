target extended-remote localhost:3333

# to debug single core:
# in u-boot: setenv smp off ; boot

# substitute appropriate value from u-boot startup message (relocation offset)
add-symbol-file ../../../u-boot/u-boot 0x3af3a000
add-symbol-file ../../../arm-trusted-firmware/build/rpi3/debug/bl31/bl31.elf 0x08400000
add-symbol-file ../../../optee_os/out/arm/core/tee.elf 0x08420000
add-symbol-file ../../../linux/vmlinux 0xffffffc000080800

mon gdb_breakpoint_override hard

flushregs

# bl31_entrypoint
#b *0x08400000

# TEE entrypoint
#b *0x08420000

# Linux; primary core entry. 
# Symbols for initial setup _do not align with vmlinux (elf)_. Debug at instruction
# level only.
# Symbols post MMU enable are correct.
#b *0x080000

mon halt
