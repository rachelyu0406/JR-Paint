main:
    addi $s0, $0, 40        # x position
    addi $s1, $0, 30        # y position
    addi $s2, $0, 2440      # top-left cell index = 30*80 + 40
    addi $s3, $0, 0         # last frame toggle
    addi $s4, $0, 8192      # canvas MMIO base
    addi $s5, $0, 4096      # BTNU MMIO
    addi $s6, $0, 4097      # BTND MMIO
    addi $s7, $0, 4098      # BTNL MMIO
    addi $t0, $0, 4099      # BTNR MMIO
    addi $t1, $0, 4100      # frame-toggle MMIO
    addi $a3, $0, 4101      # cursor x MMIO
    addi $v0, $0, 4102      # cursor y MMIO
    addi $t7, $0, 4103      # BTNC MMIO
    addi $a1, $0, 4104      # switch MMIO
    addi $a2, $0, 4105      # LED17 MMIO
    addi $t2, $0, 0         # current draw color = none
    addi $t3, $0, 80        # one canvas row
    addi $t8, $0, 4800      # total canvas cells
    addi $t4, $0, 1         # switch 0 mask
    addi $t9, $0, 2         # switch 1 mask
    addi $at, $0, 4         # switch 2 mask
    addi $ra, $0, 8         # switch 3 mask
    addi $fp, $0, 1         # next color stamp
    addi $v1, $0, 0         # previous switch state
    addi $k0, $0, 0         # black stamp
    addi $k1, $0, 0         # red stamp
    addi $gp, $0, 0         # green stamp
    addi $sp, $0, 0         # blue stamp

    sw $s0, 0($a3)
    sw $s1, 0($v0)
    sw $t2, 0($a2)
    add $a0, $s4, $s2
    sw $t2, 0($a0)

loop_wait:
    lw $a0, 0($t1)
    bne $a0, $s3, frame_ready
    j loop_wait

frame_ready:
    add $s3, $a0, $0
    lw $a0, 0($t7)
    bne $a0, $0, do_clear
    addi $t4, $0, 1
    lw $a0, 0($a1)

    and $t5, $a0, $t4
    and $t6, $v1, $t4
    bne $t5, $t6, sw0_changed
    j sw1_edge

sw0_changed:
    bne $t5, $0, sw0_on
    j sw1_edge

sw0_on:
    add $k0, $fp, $0
    addi $fp, $fp, 1

sw1_edge:
    and $t5, $a0, $t9
    and $t6, $v1, $t9
    bne $t5, $t6, sw1_changed
    j sw2_edge

sw1_changed:
    bne $t5, $0, sw1_on
    j sw2_edge

sw1_on:
    add $k1, $fp, $0
    addi $fp, $fp, 1

sw2_edge:
    and $t5, $a0, $at
    and $t6, $v1, $at
    bne $t5, $t6, sw2_changed
    j sw3_edge

sw2_changed:
    bne $t5, $0, sw2_on
    j sw3_edge

sw2_on:
    add $gp, $fp, $0
    addi $fp, $fp, 1

sw3_edge:
    and $t5, $a0, $ra
    and $t6, $v1, $ra
    bne $t5, $t6, sw3_changed
    j choose_color

sw3_changed:
    bne $t5, $0, sw3_on
    j choose_color

sw3_on:
    add $sp, $fp, $0
    addi $fp, $fp, 1

choose_color:
    addi $t2, $0, 0
    addi $t5, $0, 0

    and $t6, $a0, $t4
    bne $t6, $0, black_active
    j red_check

black_active:
    add $t5, $k0, $0

red_check:
    and $t6, $a0, $t9
    bne $t6, $0, red_active
    j green_check

red_active:
    blt $t5, $k1, set_red
    j green_check

set_red:
    add $t5, $k1, $0
    addi $t2, $0, 2

green_check:
    and $t6, $a0, $at
    bne $t6, $0, green_active
    j blue_check

green_active:
    blt $t5, $gp, set_green
    j blue_check

set_green:
    add $t5, $gp, $0
    addi $t2, $0, 3

blue_check:
    and $t6, $a0, $ra
    bne $t6, $0, blue_active
    j color_ready

blue_active:
    blt $t5, $sp, set_blue
    j color_ready

set_blue:
    addi $t2, $0, 4

color_ready:
    sw $t2, 0($a2)
    addi $t5, $0, 58        # y must stay < 58 to move down
    addi $t6, $0, 78        # x must stay < 78 to move right
    addi $t4, $0, 0         # moved flag
    bne $v1, $0, store_switches
    bne $t2, $0, start_draw
    j store_switches

start_draw:
    addi $t4, $0, 1

store_switches:
    add $v1, $a0, $0

    lw $a0, 0($s5)
    bne $a0, $0, try_up

check_down:
    lw $a0, 0($s6)
    bne $a0, $0, try_down

check_horizontal:
    lw $a0, 0($s7)
    bne $a0, $0, try_left

check_right:
    lw $a0, 0($t0)
    bne $a0, $0, try_right

after_moves:
    bne $t4, $0, do_paint
    j loop_wait

try_up:
    bne $s1, $0, do_up
    j check_down

do_up:
    addi $s1, $s1, -1
    sub $s2, $s2, $t3
    addi $t4, $0, 1
    j check_horizontal

try_down:
    blt $s1, $t5, do_down
    j check_horizontal

do_down:
    addi $s1, $s1, 1
    add $s2, $s2, $t3
    addi $t4, $0, 1
    j check_horizontal

try_left:
    bne $s0, $0, do_left
    j check_right

do_left:
    addi $s0, $s0, -1
    addi $s2, $s2, -1
    addi $t4, $0, 1
    j after_moves

try_right:
    blt $s0, $t6, do_right
    j after_moves

do_right:
    addi $s0, $s0, 1
    addi $s2, $s2, 1
    addi $t4, $0, 1

do_paint:
    sw $s0, 0($a3)
    sw $s1, 0($v0)
    bne $t2, $0, paint_cell
    j loop_wait

paint_cell:
    add $a0, $s4, $s2
    sw $t2, 0($a0)
    j loop_wait

do_clear:
    addi $s0, $0, 40
    addi $s1, $0, 30
    addi $s2, $0, 2440
    sw $s0, 0($a3)
    sw $s1, 0($v0)
    addi $a0, $0, 0

clear_loop:
    add $t5, $s4, $a0
    sw $0, 0($t5)
    addi $a0, $a0, 1
    blt $a0, $t8, clear_loop

clear_wait:
    lw $a0, 0($t7)
    bne $a0, $0, clear_wait
    j loop_wait

# MMIO map used by the top file:
# 4096: BTNU
# 4097: BTND
# 4098: BTNL
# 4099: BTNR
# 4100: frame toggle, flips once per screen refresh
# 4101: live cursor x position in grid cells
# 4102: live cursor y position in grid cells
# 4103: BTNC, clears the canvas and recenters the cursor
# 4104: SW[3:0], black/red/green/blue select
# 4105: LD17 RGB color code
# 8192 + n: canvas cell n, 0 <= n < 4800
