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

#define MODE_QVGA8              113             /* Like mode 13 but with a magic palette */
#define MODE_QVGA16             114             /* Like mode 13 but 16BPP */
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
        stmfd   r13!, {r8, r12, lr}

        ldr     r12, [r12]

mode_extension:
        ldr     r8, [r12, #WS_OFFS_FLAGS]

        cmp     r2, #MODE_QVGA8
        bne     1f

        /* MODE_QVGA8 */

        /* We're going into an extended palette mode: set the flag */
        orr     r8, r8, #WS_FLAG_EXT
        str     r8, [r12, #WS_OFFS_FLAGS]

        /* The PaletteV default palette vector seems to be called on
         * new modes, so we don't need to call it here.
         */

        adr     r3, mode_320_256_8_vidc_list
        adr     r4, mode_320_256_8_ws_list
        /* Return having claimed this call: */
        mov     r1, #0
        b       out

1:      cmp     r2, #MODE_QVGA16
        bne     not_my_mode

        /* MODE_QVGA16 */

        /* Clear extended palette mode */
        bic     r8, r8, #WS_FLAG_EXT
        str     r8, [r12, #WS_OFFS_FLAGS]

        adr     r3, mode_320_256_16_vidc_list
        adr     r4, mode_320_256_16_ws_list
        /* Return having claimed this call: */
        mov     r1, #0
        b       out

out:
        ldmfd   r13!, {r8, r12, pc}^

not_my_mode:
        /* Clear the extended palette flag: */
        bic     r8, r8, #WS_FLAG_EXT
        str     r8, [r12, #WS_OFFS_FLAGS]

        b       out

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
        .long   4                       /* Log2BPP */
        .long   10
        .long   4                       /* Log2BPC, 8 pixels = 16 bytes */
        .long   11
        .long   319                     /* XWindLimit */
        /* The remainder (Y-oriented values) are the same as the base mode 13 */
        .long   -1

        .end
