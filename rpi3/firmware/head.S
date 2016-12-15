/*
 * Copyright (c) 2016, Linaro Limited
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
/*
 * Reverse-engineered from head.bin previously committed in the Git repository.
 * Build with:
 *   aarch64-linux-gnu-as head.S -o head.o
 *   aarch64-linux-gnu-objcopy -O binary head.o head.bin
 */
		mov	x0, #0x40000000
		str	wzr, [x0]
		mov	w1, #0x80000000
		str	w1, [x0, #8]

		ldr	x0, _19_2_MHz
		msr	cntfrq_el0, x0

		msr	cntvoff_el2, xzr

		mov	x0, #0x33ff
		msr	cptr_el3, x0

		mov	x0, #0x5b0
		msr	scr_el3, x0

		mov	x0, #0x40
		msr	s3_1_c15_c2_1, x0

		mrs	x6, mpidr_el1
		and	x6, x6, #0x3
		cbz	x6, core0

		adr	x5, spin_table
spin:
		wfe
		ldr	x4, [x5, x6, lsl #3]
		cbz	x4, spin
		mov	x0, #0x0
		b	1f
core0:
		ldr	x4, core0_init
		ldr	x0, core0_init_parm
1:
		mov	x1, #0x0
		mov	x2, #0x0
		mov	x3, #0x0
		br	x4

_19_2_MHz:
		.word	0x0124f800
		.rept	23
		.word	0x0
		.endr
		.balign	8, 0
core0_init:
		.word	0x8000
		.balign	8, 0
spin_table:
		.rept	8
		.word	0x0
		.endr
core0_init_parm:
		.word	0x100
		.p2align	15, 0

