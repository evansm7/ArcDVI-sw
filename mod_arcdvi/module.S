/* arcdvi support module for RISC OS
 *
 * MIT License
 *
 * Copyright (c) 2021-2022 Matt Evans
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


        .text
        .org    0
        .globl _start
_start:
        //////////////////////////////////////////////////////////////////////
        // Header
module_header:
        .long   0               // No run/start code
        .long   init
        .long   fini
        .long   service_call
        .long   str_title
        .long   str_help
        .long   cmd_table
        .long   0               // No SWI Chunk number
        .long   0               // No SWI handler
        .long   0               // No SWI names
        .long   0               // No SWI decoder
        .long   0               // No messages
        .long   0               // No module flags


        //////////////////////////////////////////////////////////////////////
        // Fini
fini:
        stmfd   r13!, {r0-r12,r14}

        ldr     r12, [r12]

        // Release claimed vector:
        bl      get_vector_palettev
        mov     r1, r0
        mov     r0, #Vector_PaletteV
        mov     r2, r12
        swi     SWI_OS_RELEASE | SWI_X
        bvs     fail_err_return

        // If workspace was allocated, free it:
        cmp     r12, #0
        beq     1f

        mov     r0, #7          // Free
        mov     r2, r12
        swi     SWI_OS_MODULE | SWI_X
        bvs     fail_err_return

1:      ldmfd   r13!, {r0-r12, pc}^


        //////////////////////////////////////////////////////////////////////
        // Initialisation

        /* Entry:
         *      r0 = environment/init parameters
         *      r11 = IO base/instantiation number
         *      r12 = private word
         *      r13 = SVC stack
         *      r14 = return
         *
         * Return:
         *      V clear on success
         *      V set, r0 = error block
         */
init:
        stmfd   r13!, {r0-r12,r14}

        // Is private word non-zero?
        ldr     r0, [r12]
        cmp     r0, #0
        bne     1f
        // If so, workspace already claimed & we're re-initing

        // Allocate workspace
        mov     r0, #6          // Claim space
        mov     r3, #WORKSPACE_SZ
        swi     SWI_OS_MODULE | SWI_X
        bvs     fail_err_return
        str     r2, [r12]
1:
        ldr     r12, [r12]
        // Init workspace

        // Claim PaletteV:
        bl      get_vector_palettev
        mov     r1, r0
        mov     r0, #Vector_PaletteV
        mov     r2, r12
        swi     SWI_OS_CLAIM | SWI_X
        bvs     fail_err_return

#ifdef VERBOSE
        // This is super-annoying to the end user, but useful during dev!
        adr     r0, hello_string
        swi     SWI_OS_WRITE0 | SWI_X
        bvs     fail_err_return
#endif

        // Finished!
        ldmfd   r13!,{r0-r12,pc}^

fail_err_return:
        add     r13, r13, #4
        ldmfd   r13!, {r1-r12,lr}
        orrs    pc, lr, #V_BIT

#ifdef VERBOSE
hello_string:
        .ascii "ArcDVI initialising, built "
        .ascii BUILD_DATE
        .asciz "\r\n"
        .align
#endif


        //////////////////////////////////////////////////////////////////////
        // Strings

str_title:      .asciz "ArcDVI"
str_help:       .asciz "ArcDVI	0.01 (" BUILD_DATE ")"
        .align

        ////////////////////////////////////////////////////////////////
.pool
_end:
.end

