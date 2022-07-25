# ArcDVI-sw: Digital video output for the Acorn Archimedes

26 July 2022

ArcDVI is a hardware add-on allowing Acorn Archimedes computers to output video via DVI.  Retrocompute on a _quality_ monitor! :)

The ArcDVI project comprises several parts:

   * The [PCB designs](https://github.com/evansm7/ArcDVI-PCB), which contain an FPGA and microcontroller
   * The [FPGA design](https://github.com/evansm7/ArcDVI-hw)
   * The microcontroller [firmware](https://github.com/evansm7/ArcDVI-fw)
   * Optional extension/test [software](https://github.com/evansm7/ArcDVI-sw) for RISC OS  (__This repo__)


This repository contains source for a RISC OS modes extension module in `mod_arcdvi/`, providing 32K colour and 256-colour Extended Palette modes.

The mode numbers are subject to change (see the source), except for mode 107 which is intended to match the CC ColourCard mode 107 of 576x424 in 32K colours.

The modes are currently:

   * 576x424 in 32K colours: mode 107 (looks great, but uses ALL the screen memory & bandwidth)
   * 320x256 in 32K colours (can be double-buffered)
   * Versions of modes 13, 15, 21 and 28 in 256 colours, with Extended Palette (all 256 freely programmable from 16.7M colours)

There are some simple BASIC programs to demonstrate these modes in `basic_test/`, including palette cycling in the 256 colour modes.


## Building the module

On a POSIX-like machine with an `arm-none-eabi` toolchain installed:

```
[~/ArcDVI-sw]$ cd mod_arcdvi
[~/ArcDVI-sw/mod_arcdvi]$ make
```
The output is `module`, which can be transferred to the Arc (filetype Module).


## References

(This link will probably break eventually, but) There's an ArcDVI thread on the StarDot forums with some photos/development notes:  <https://stardot.org.uk/forums/viewtopic.php?f=16&t=23772>


## Copyrights & licence

Copyright 2021-2022 Matt Evans, and provided under the MIT licence.
