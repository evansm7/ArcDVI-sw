/* Service call handlers
 *
 * MIT License
 *
 * Copyright (c) 2022 Matt Evans
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include "riscos_defs.h"
#include "module.h"

#define VIDC_CR_EXTPAL_BIT      (1 << 23)
#define VIDC_CR_EXTBPP_BIT      (1 << 22)

        .text
        .globl service_call

        //////////////////////////////////////////////////////////////////////
        // Handler
service_call:
        // r1 = service number
        // r12 = pointer to module private word

        teq     r1, #Service_ModeExtension
        movnes  pc, lr

        // r2 = requested mode number
        // r3 = Monitor type (or -1)
        stmfd   r13!, {r5-r12, lr}

        ldr     r12, [r12]

mode_extension:
        /* Look for a matching mode. */
        adr     r11, modes_list
        mov     r10, r11
1:      ldm     r10!, {r5-r8}
        cmp     r5, #-1
        beq     not_my_mode
        cmp     r5, r2
        bne     1b

        tst     r6, #1                  /* Flag ext. pal? */
        ldr     r9, [r12, #WS_OFFS_FLAGS]
        orrne   r9, r9, #WS_FLAG_EXT
        biceq   r9, r9, #WS_FLAG_EXT
        str     r9, [r12, #WS_OFFS_FLAGS]

        /* The PaletteV default palette vector seems to be called on
         * new modes, so we don't need to call it here.
         */

        add     r3, r11, r7              /* VIDC reg list */
        add     r4, r11, r8              /* Workspace list */
        /* Return having claimed this call: */
        mov     r1, #0

out:
        ldmfd   r13!, {r5-r12, pc}^

not_my_mode:
        /* Clear the extended palette flag: */
        bic     r8, r8, #WS_FLAG_EXT
        str     r8, [r12, #WS_OFFS_FLAGS]

        b       out

        //////////////////////////////////////////////////////////////////////
        // Custom modes

	/*
	 *  _   _       _       _
	 * | \ | | ___ | |_ ___| |
	 * |  \| |/ _ \| __/ _ \ |
 	 * | |\  | (_) | ||  __/_|
	 * |_| \_|\___/ \__\___(_)
         *
         * These screen modes are defined for testing only: the numbers and
         * attributes WILL CHANGE!
         *
         */

modes_list:
        .long   113                     /* Like mode 13, but extended 256 */
        .long   1                       /* Flags: extended palette */
        .long   mode_320_256_8_vidc_list - modes_list
        .long   mode_320_256_8_ws_list - modes_list

        .long   114                     /* Like mode 13, but high-colour */
        .long   0                       /* Flags: No extended palette */
        .long   mode_320_256_16_vidc_list - modes_list
        .long   mode_320_256_16_ws_list - modes_list

        .long   115                     /* Like mode 15, but extended 256 */
        .long   1
        .long   mode_640_256_8_vidc_list - modes_list
        .long   mode_640_256_8_ws_list - modes_list

        .long   -1
        .long   -1
        .long   -1
        .long   -1


        //////////////////////////////////////////////////////////////////////
mode_320_256_8_vidc_list:
        .long   0                       /* List format */
        .long   13                      /* Based on mode 13, except... */
        .long   (0x38 << 26) | 0x000000ac | VIDC_CR_EXTPAL_BIT       /* CR.EXTPAL=1 */
        .long   -1

mode_320_256_8_ws_list:
        .long   0                       /* List format */
        .long   13                      /* Based on mode 13 */
        /* No custom VDU variables */
        .long   -1

mode_640_256_8_vidc_list:
        .long   0                       /* List format */
        .long   15                      /* Based on mode 15, except... */
        .long   (0x38 << 26) | 0x0000009e | VIDC_CR_EXTPAL_BIT       /* CR.EXTPAL=1 */
        .long   -1

mode_640_256_8_ws_list:
        .long   0                       /* List format */
        .long   15                      /* Based on mode 15 */
        /* No custom VDU variables */
        .long   -1

mode_320_256_16_vidc_list:
        .long   0                       /* List format */
        .long   15                      /* Based on mode 13 timings, except... */
        .long   (0x38 << 26) | 0x0000009e | VIDC_CR_EXTBPP_BIT       /* CR.EXTBPP=1 */
        .long   -1

mode_320_256_16_ws_list:
        .long   0                       /* List format */
        .long   13                      /* Based on mode 13 */
        /* Custom VDU variables */
        .long   4
        .long   2                       /* XEigFactor: 320px in 1280 coordinates, 2**2 per pixel */
        .long   6
        .long   640                     /* LineLength: in bytes */
        .long   7
        .long   320*256*2               /* ScreenSize: in bytes */
        .long   9
        .long   4                       /* Log2BPP (I interpret this as memory-used-per-px, i.e. 2 bytes) */
        .long   10
        .long   4                       /* Log2BPC, 8 pixels = 16 bytes */
        .long   11
        .long   319                     /* XWindLimit */
        /* The remainder (Y-oriented values) are the same as the base mode 13 */
        .long   -1

        .end
