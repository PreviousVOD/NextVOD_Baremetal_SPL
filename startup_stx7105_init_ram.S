/*
 * (C) Copyright 2004-2009 STMicroelectronics.
 *
 * Andy Sturges <andy.sturges@st.com>
 * Start Menefy <stuart.menefy@st.com>
 * Sean McGoogan <Sean.McGoogan@st.com>
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

/* These macros are compatible to STLinux U-boot. */

#define POKE32(addr, value)           .long 0x00000004, addr, value
#define UPDATE32(addr, mask, value)   .long 0x00000006, addr, mask, value
#define WHILE_NE32(addr, mask, value) .long 0x00000007, addr, mask, value
#define DELAY(val)                    /* ST did nothing  */
#define END_MARKER                    .long 0x00000000, 0x00000000, 0x00000000


/* Poke operation list */
    .section .rodata.init, "a"
__memory_setup_table:
    #include "vendor/pdk7105.romgen"

    /*
     * Note that we also manually need to move the LMI base addresses to
     * their 32-bit SE mode locations as defined in the datasheet and change the
     * 'upper bound addresses' (in row attribute registers) for the LMIs.
     */

    /* STX7105_SYSCONF_SYS_CFG38 */
    UPDATE32(0xfe001000 + 0x0198, 0xFFFFFF00, 0x00000040)

    /*
     * Change LMI upper bound addresses
     * Upper LMI addr=0x40000000 + 512MiB=0x60000000
     */

    /* ST40_LMI_SDRA0_0 -> ST40_LMI_REGS_BASE + 0x000030 */
    UPDATE32(0xFE901000 + 0x30, 0x001FFFFF, 0x60000000)

    /* ST40_LMI_SDRA1_0 -> ST40_LMI_REGS_BASE + 0x000038 */
    UPDATE32(0xFE901000 + 0x38, 0x001FFFFF, 0x60000000)

    END_MARKER

__memory_setup_table_end:
    .long 0x00000000

/*
 *    NOTE:     ALL THIS CODE MUST BE PIC !!!!
 *
 *    This code expects to be run with the caches enabled.
 */

    .section .text.init, "ax"
    .global _memory_setup_init_ram

_memory_setup_init_ram:
    /* Stash the pr somewhere safe */
    sts    pr, r14

    /*
     * We need to get the poke loop & associated data
     * into caches. The poke loop is structured so that it is
     * all pulled into cache on it 1st iteration.
     * To get the poke table into D-cache, we simply read it all.
     */

    mova _init_ram_poke_loop_address, r0    /* R6: &poke_loop() */
    mov.l @r0, r6
    add r0, r6
    mov.l _init_ram_p2_to_p1_mask, r3       /* R3: P2 -> P1 mapping */
    and r3, r6                    /* convert to P1 addresses */
    mov.l _init_ram_data_start_address, r1  /* R1 = start address */
    add r0, r1
    mov.l _init_ram_data_end_address, r2    /* R2 = end address */
    add r0, r2
    and r3, r1                    /* convert to a P1 addresses */
    and r3, r2
    mov r1, r5                    /* R5 = scratch data ptr */

1:
    mov.l @r5+, r4                /* Load poke table in D$ */
    cmp/eq r5, r2
    bf 1b

    /*
     * Its now safe to call the poke loop with real data, since it
     * and its associated data table are in onchip caches. Setting
     * up the memory interfaces may cause the EMI (where this FLASH
     * image resides) to briefly hang - but the CPU will be safely
     * executing from cache should this happen.
     */
do_pokes:
    jsr    @r6        /* R6 still points poke_loop() */
      nop

    /* Restore the PR */
    lds    r14, pr
    rts
      nop


    .balign 4
_init_ram_poke_loop_address:  .long _init_ram_poke_loop - _init_ram_poke_loop_address
_init_ram_data_start_address: .long __memory_setup_table - _init_ram_poke_loop_address
_init_ram_data_end_address:   .long __memory_setup_table_end - _init_ram_poke_loop_address
_init_ram_p2_to_p1_mask:      .long ~0x20000000


/*
 * This is derived from STMicroelectronics gnu toolchain example:
 *    sh-superh-elf/examples/os21/romdynamic/bootstrap.S
 * but it is not identical, because concurrently U-Boot added the
 * IF_DEVID, IF_NOT_DEVID, ELSE and ENDIF commands, while the toolset
 * added IF. This merged version supports both.
 */

/*
 * The poke table is a series of long words, in the format
 *
 *    opcode, address, operand, ...
 *
 * An opcode of 0 marks the table end
 */

/*
 * Routine to setup peripheral registers.
 * It is executed from within the I-cache,
 * with all its data in the D-cache
 */
_init_ram_poke_loop:
    mov.l    @r1+, r0    /* opcode */
    mov.l    @r1+, r2    /* address */
    mov.l    @r1+, r3    /* value */

    cmp/eq    #0, r0        /* End marker ? */
    bf    1f

    rts            /* Return point */
    nop

1:
    cmp/eq    #4, r0        /* 4 byte write... */
    bf    1f
    mov.l    r3, @r2

1:
    cmp/eq    #2, r0        /* 2 byte write... */
    bf    1f
    mov.w    r3, @r2

1:
    cmp/eq    #1, r0        /* 1 byte write... */
    bf    1f
    mov.b    r3, @r2

1:
    cmp/eq    #5, r0        /* 4 byte OR... */
    bf    1f
    mov.l    @r2,r4
    or    r3,r4
    mov.l    r4,@r2

1:
    cmp/eq    #6, r0        /* 4 byte UPDATE... */
    bf    1f
    mov.l    @r2,r4
    and    r3,r4
    mov.l    @r1+,r3
    or    r3,r4
    mov.l    r4,@r2

1:
    cmp/eq    #8, r0        /* 4 byte write UPDATE... */
    bf    1f
    mov.l    @r3,r4
    mov.l    @r1+,r3
    and    r3,r4
    mov.l    @r1+,r3
    shld    r3,r4
    mov.l    @r1+,r3
    or    r3,r4
    mov.l    r4,@r2

1:
    cmp/eq    #7, r0        /* WHILE != ... */
    bf    1f
    mov.l    @r1+,r5

2:
    mov.l    @r2,r4
    and    r3,r4
    cmp/eq    r4,r5
    bf    2b

1:
    cmp/eq    #9, r0        /* IF_DEVID */
    bf    1f        /* r2 skip offset, r3 condition, r7 holds out cut value */
    cmp/eq    r3, r7
    bt    _init_ram_poke_loop    /* go ahead with these pokes */
    add    r2, r1
    bra    _init_ram_poke_loop
      nop

1:
    cmp/eq    #10, r0        /* IF_NOT_DEVID */
    bf    1f        /* r2 skip offset, r3 condition, r7 holds out cut value */
    cmp/eq    r3, r7
    bf    _init_ram_poke_loop    /* go ahead with these pokes */
    add    r2, r1
    bra    _init_ram_poke_loop
      nop

1:    cmp/eq    #11, r0        /* ELSE */
    bf    1f        /* r2 skip offset, r3 condition, r7 holds out cut value */
    add    r2, r1
    bra    _init_ram_poke_loop
      nop

1:
    cmp/eq    #12,r0        /* IF == ... next op */
    bf    _init_ram_delay
    mov.l    @r1+,r5
    mov.l    @r2,r4
    and    r3,r4
    cmp/eq    r4,r5
    bt    _init_ram_poke_loop    /* Compare succeeded - perform next op */

2:                /* Skip the next operation (read past it) */
    mov.l    @r1+,r0        /* R0 = opcode */
    mov.l    @r1+,r2        /* skip address */
    mov.l    @r1+,r2        /* skip value */
                /* How many further reads do we need to skip? */
    cmp/eq    #12,r0        /* If it's another IF, skip 1 and go back to start of skip loop */
    bf    3f
    mov.l    @r1+,r2
    bra    2b
    nop

3:
    mov    #5,r2
    cmp/gt    r2,r0
    bf    5f        /* 0 further reads */

    cmp/eq    #8,r0        /* Is it number 8 (3 reads, otherwise 1 read) */
    bf    4f
    mov.l    @r1+,r2        /* Skip 1 read */
    mov.l    @r1+,r2        /* Skip 1 read */
4:
    mov.l    @r1+,r2        /* Skip 1 read and continue */
5:
    bra    _init_ram_poke_loop
    nop

_init_ram_delay:
    mov    #1,r0        /* small delay after EACH opcode */
    swap.w    r0, r0        /* 0x10000 iterations (~65k) */

2:
    add    #-1,r0
    cmp/eq    #0, r0
    bf    2b
    bt    _init_ram_poke_loop
