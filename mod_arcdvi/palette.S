/* Palette setup and vector handlers
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


#define VIDC_BASE       0x03400000
#define VIDC_MAGIC0     0x50000000
#define VIDC_PAYLOAD    0x54000000


        .text
        .globl palette_default

        // r12 = module workspace
        // It turns out that this shouldn't write directly to the video controller,
        // but should use VDU19 or ColourTrans_WritePalette which in turn bounce
        // through PaletteV's write palette, which writes the video controller.
palette_default:
        stmfd   r13!, {r0-r5, r9-r12, lr}

        /* Construct BGR like VIDC's 8bpp:
         *
         * Given pixel pix[7:0] and palette pal[11:0] = palette[pix[3:0]]
         * R[3:0] = pix[4],pal[2:0]
         * G[3:0] = pix[6:5],pal[5:4]
         * B[3:0] = pix[7],pal[10:8]
         *
         * Then, expand 12 to 24 bit 00BBGGRR, i.e.:
         * R[7:0] = pix[4],pal[2:0],{pal[0] x 4}
         * G[7:0] = pix[6:5],pal[5:4],{pal[4] x 4}
         * B[7:0] = pix[7],pal[10:8],{pal[8] x 4}
         */
        mov     r0, #0
        adr     r1, vidc_256_pal

        mov     r9, #VIDC_BASE
        add     r12, r12, #WS_OFFS_PALETTE
        add     r11, r12, #WS_OFFS_SCRATCH
1:
        and     r2, r0, #0xf
        ldr     r3, [r1, r2, lsl#2]     // r3 = palette[pix[3:0]]

        /* Red: */
        and     r4, r0, #0x10
        mov     r4, r4, lsl#3           // R[7]
        and     r5, r3, #0x007
        orr     r4, r4, r3, lsl#4       // R[6:4]
        tst     r3, #0x001
        orrne   r4, r4, #0xf            // R[3:0]

        /* Green */
        and     r5, r0, #0x60
        orr     r4, r4, r5, lsl#8+1     // G[7:6]
        and     r5, r3, #0x030
        orr     r4, r4, r5, lsl#8+0     // G[5:4]
        tst     r3, #0x010
        orrne   r4, r4, #0xf00          // G[3:0]

        /* Blue */
        and     r5, r0, #0x80
        orr     r4, r4, r5, lsl#16+0    // B[7]
        and     r5, r3, #0x700
        orr     r4, r4, r5, lsl#16-8+4  // B[5:4]
        tst     r3, #0x100
        orrne   r4, r4, #0x0f0000       // B[3:0]

        /* Store to shadow palette */
        str     r4, [r12, r0, lsl#2]    // xxBBGGRR
        mov     r4, r4, lsl#8
        /* Store to scratch palette */
        str     r4, [r11, r0, lsl#2]    // BBGGRRxx

        // Loop
        add     r0, r0, #1
        cmp     r0, #256
        blt     1b

        // //////// Use ColourTrans_WritePalette
        mov     r0, #-1
        mov     r1, #-1
        mov     r2, r11
        mov     r3, #0
        mov     r4, #0
        swi     SWI_COLOURTRANS_WRITEPALETTE

        ldmfd   r13!, {r0-r5, r9-r12, pc}^

vidc_256_pal:
        /* The default 16-entry VIDC palette
         * used by RISC OS for 256 colour modes:
         */
        .long 0x000, 0x111, 0x222, 0x333, 0x004, 0x115, 0x226, 0x337
        .long 0x400, 0x511, 0x622, 0x733, 0x404, 0x515, 0x626, 0x737


        .globl palette_grey

        // r12 = module workspace
palette_grey:
        stmfd   r13!, {r0-r5, r9-r12}
        /* Construct BBGGRR 8-bit grey
         */
        mov     r0, #0

        mov     r9, #VIDC_BASE
        mov     r10, #VIDC_MAGIC0
        add     r12, r12, #WS_OFFS_PALETTE
1:

        mov     r4, r0                  /* Red: */
        orr     r4, r4, r0, lsl#8       /* Green */
        orr     r4, r4, r0, lsl#16      /* Blue */

        /* Store to shadow palette */
        str     r4, [r12, r0, lsl#2]

        /* Write BBGGRR to VIDC extended regs: PAYLOAD (data payload) */
        orr     r4, r4, #VIDC_PAYLOAD
        str     r4, [r9]

        /* Write palette inded to MAGIC0 (bits [7:0], bits [11:8] are 0 for "load pal"): */
        orr     r4, r0, #VIDC_MAGIC0
        str     r4, [r9]                /* Loads payload */

        // Loop
        add     r0, r0, #1
        cmp     r0, #256
        blt     1b

        ldmfd   r13!, {r0-r5, r9-r12}
        movs    pc, lr


        .globl get_vector_palettev
get_vector_palettev:
        adr     r0, vector_palettev
        mov     pc, lr


        .globl vector_palettev
vector_palettev:
        /* r4 = reason code
         * r12 = workspace
         *
         * This vector is claimed so responses can be given to palette
         * write/read ops and use the extended palette.  However,
         * this isn't done when the machine isn't flagged as being in
         * an extended palette mode.
         */
        stmfd   r13!, {r0-r5, lr}
        ldr     r5, [r12, #WS_OFFS_FLAGS]
        tst     r5, #WS_FLAG_EXT
        beq     palettev_exit

        /* OK, extended mode, what's the reason code? */
        cmp     r4, #1                  /* Is it read palette? */
        bne     1f

read_palette:
        /* Further reason codes:
         * r0 = logical colour
         * r1 = type of colour:
         *      16 = Normal
         *      17/18 = flashing colours
         *      24 = border
         *      25 = pointer
         *
         */
        cmp     r1, #16
        cmpne   r1, #17
        cmpne   r1, #18
        beq     read_palette_regular

        cmp     r1, #24
        beq     read_palette_dummy
        /* Otherwise, pointer, which we hand back */
        b       palettev_exit

read_palette_regular:
        and     r3, r0, #0xff
        add     r2, r12, #WS_OFFS_PALETTE
        ldr     r2, [r2, r3, lsl#2]
        mov     r2, r2, lsl#8           /* From xxBBGGRR to BBGGRRxx */
        mov     r3, r2                  /* Fake the flashing colours */
        b       read_palette_out

read_palette_dummy:
        mov     r2, #0
        mov     r3, #0

read_palette_out:
        str     r2, [r13, #4*2]
        str     r3, [r13, #4*3]
        b       palettev_success

1:      cmp     r4, #2                  /* Is it write palette? */
        bne     1f

write_palette:
        /* Further choices here too:
         * r0 = logical colour
         * r1 = type of colour
         * r2 = first flash colour
         * r3 = second flash colour
         *
         * We support only the case where type=16 and r2=r3
        */
        cmp     r1, #25                 /* Pointer */
        beq     palettev_exit           /* Hand it back */

        cmp     r1, #16
        cmpeq   r2, r3
        bne     palettev_success        /* .. we ignore the tricky requests. :P */

        and     r0, r0, #0xff
        /* OK, set the colour in r2 to index r0: */
        mov     r2, r2, lsr#8           /* From BBGGRRxx to xxBBGGRR */

        add     r4, r12, #WS_OFFS_PALETTE
        str     r2, [r4, r0, lsl#2]     /* Update shadow palette */

        /* Now, poke VIDC: */
        mov     r12, #VIDC_BASE
        orr     r2, r2, #VIDC_PAYLOAD
        str     r2, [r12]               /* Write PAYLOAD (data payload) with colour */
        orr     r0, r0, #VIDC_MAGIC0
        str     r0, [r12]               /* Write MAGIC0 (op) with index */
        b       palettev_success

1:      cmp     r4, #5                  /* Is it set defaults? */
        bne     1f

set_default_palette:
        /* This seems to be called when changing to a new screen mode */
        bl      palette_default
        b       palettev_success

1:      /* Unknown or unhandled reason code, just exit. */
        b       palettev_exit

palettev_success:
        mov     r4, #0                  /* Handled */
        str     r4, [r13, #4*4]

palettev_exit:
        ldmfd   r13!, {r0-r5, lr}
        bics    pc, r14, #V_BIT         /* Other vectors in the docs say something about V being error ... */

        .end
