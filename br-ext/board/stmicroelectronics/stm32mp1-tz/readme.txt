STM32MP1 Based platforms

Intro
=====

This directory provides support for few STM32MP1 based development boards.

  https://www.st.com/en/evaluation-tools/stm32mp157a-dk1.html
  https://www.st.com/en/evaluation-tools/stm32mp157c-dk2.html
  https://www.st.com/en/evaluation-tools/stm32mp157c-ev1.html

How to build
============

From OP-TEE build repository:

 $ make PLATFORM=stm32mp1-157A_DK1 all
or
 $ make PLATFORM=stm32mp1-157C_DK2 all
or
 $ make PLATFORM=stm32mp1-157C_EV1 all

How to write the microSD card
=============================

Once the build process is finished you will have an image called
"sdcard.img" in directory ../out-br/images/ (relative to build
repository root path).

Copy the bootable "sdcard.img" onto an microSD card with "dd":

  $ sudo dd if=../out-br/images/sdcard.img of=/dev/sdX \
	    conv=fdatasync status=progress

Boot the board
==============

 (1) Insert the microSD card in connector CN15

 (2) Plug a micro-USB cable in connector CN11 and run your serial
     communication program on /dev/ttyACM0.

 (3) Plug a USB-C cable in CN6 to power-up the board.

 (4) The system will start, with the console on UART. Both secure
     and non-secure console consoles are on the same UART bus.
