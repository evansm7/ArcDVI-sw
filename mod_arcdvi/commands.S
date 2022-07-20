/* Module command table, and simple commands
 *
 * MIT License
 *
 * Copyright (c) 2021 Matt Evans
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

#define VIDC_BASE       0x03400000
#define VIDC_MAGIC0     0x50000000
#define VIDC_MAGIC1     0x54000000

        .text
        .globl cmd_table

        //////////////////////////////////////////////////////////////////////
        // Commands:
cmd_table:
        .asciz  "grey_direct"  // Make grayscale mode (directly)
        .align  2       // Word-align
        .long   cmd_grey_direct
        // Flags word:
        .byte   0       // Min params
        .byte   0       // No GSTrans
        .byte   0       // Max params
        .byte   0       // Flags
        .long   0       // No syntax error message
        .long   0       // No help message

        .asciz  "grey"  // Make grayscale mode via colourtrans
        .align  2       // Word-align
        .long   cmd_grey
        // Flags word:
        .byte   0       // Min params
        .byte   0       // No GSTrans
        .byte   0       // Max params
        .byte   0       // Flags
        .long   0       // No syntax error message
        .long   0       // No help message

        .asciz  "norm"  // Restore regular 256c palette
        .align  2       // Word-align
        .long   cmd_norm
        // Flags word:
        .byte   0       // Min params
        .byte   0       // No GSTrans
        .byte   0       // Max params
        .byte   0       // Flags
        .long   0       // No syntax error message
        .long   0       // No help message

        .long   0       // End


        //////////////////////////////////////////////////////////////////////
cmd_grey_direct:
        // r0 = command tail (preserve)
        // r1 = number of OSCLI parameters
        // r12 = pointer to module private word

        stmfd   r13!, {r12, lr}

        ldr     r12, [r12]
        bl      palette_grey

        ldmfd   r13!, {r12, pc}^

cmd_grey:
        // r0 = command tail (preserve)
        // r1 = number of OSCLI parameters
        // r12 = pointer to module private word

        stmfd   r13!, {r0-r4, r11, r12, lr}

        ldr     r12, [r12]
        add     r11, r12, #WS_OFFS_PALETTE
        add     r12, r12, #WS_OFFS_SCRATCH

        mov     r1, #0
1:      mov     r0, r1, lsl#8
        orr     r0, r0, r1, lsl#16
        orr     r0, r0, r1, lsl#24
        str     r0, [r12, r1, lsl#2]            /* Write scratch entry */
        mov     r0, r0, lsr#8
        str     r0, [r11, r1, lsl#2]            /* Update shadow palette */
        add     r1, r1, #1
        cmp     r1, #256
        blt     1b
        mov     r0, #-1
        str     r0, [r12, r1, lsl#2]

        mov     r0, #-1
        mov     r1, #-1
        mov     r2, r12
        mov     r3, #0
        mov     r4, #0
        swi     SWI_COLOURTRANS_WRITEPALETTE    /* Program palette via PaletteV */

        ldmfd   r13!, {r0-r4, r11, r12, pc}^


        //////////////////////////////////////////////////////////////////////

cmd_norm:
        // r0 = command tail (preserve)
        // r1 = number of OSCLI parameters
        // r12 = pointer to module private word

        stmfd   r13!, {r12, lr}

        ldr     r12, [r12]
        bl      palette_default

        ldmfd   r13!, {r12, pc}^

        .end
