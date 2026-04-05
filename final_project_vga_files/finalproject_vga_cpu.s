main:
    addi $s0, $0, 40        # x position
    addi $s1, $0, 30        # y position
    addi $s2, $0, 2440      # cell index = 30*80 + 40
    addi $s3, $0, 0         # last frame toggle
    addi $s4, $0, 8192      # canvas MMIO base
    addi $s5, $0, 4096      # BTNU MMIO
    addi $s6, $0, 4097      # BTND MMIO
    addi $s7, $0, 4098      # BTNL MMIO
    addi $t0, $0, 4099      # BTNR MMIO
    addi $t1, $0, 4100      # frame-toggle MMIO
    addi $a3, $0, 4101      # cursor x MMIO
    addi $t7, $0, 4103      # BTNC MMIO
    addi $a1, $0, 4104      # switch MMIO
    addi $a2, $0, 4105      # LED17 MMIO
    addi $t2, $0, 0         # current draw color = none
    addi $t3, $0, 80        # one canvas row
    addi $t8, $0, 4800      # total canvas cells
    addi $t9, $0, 0         # frame divider count
    addi $gp, $0, 58        # y must stay < 58 to move down
    addi $sp, $0, 78        # x must stay < 78 to move right
    addi $fp, $0, 4         # move once every 4 frame toggles

    sw $s0, 0($a3)
    sw $s1, 1($a3)
    sw $t2, 0($a2)

loop_wait:
    lw $a0, 0($t1)
    bne $a0, $s3, frame_ready
    j loop_wait

frame_ready:
    add $s3, $a0, $0
    lw $a0, 0($t7)
    bne $a0, $0, do_clear

    add $t5, $t2, $0
    lw $a0, 0($a1)
    addi $t2, $0, 0
    addi $t4, $0, 0

    addi $v0, $0, 512
    and $v1, $a0, $v0
    bne $v1, $0, set_black

    addi $v0, $0, 256
    and $v1, $a0, $v0
    bne $v1, $0, set_brown

    addi $v0, $0, 128
    and $v1, $a0, $v0
    bne $v1, $0, set_purple

    addi $v0, $0, 64
    and $v1, $a0, $v0
    bne $v1, $0, set_blue

    addi $v0, $0, 32
    and $v1, $a0, $v0
    bne $v1, $0, set_green

    addi $v0, $0, 16
    and $v1, $a0, $v0
    bne $v1, $0, set_yellow

    addi $v0, $0, 8
    and $v1, $a0, $v0
    bne $v1, $0, set_orange

    addi $v0, $0, 4
    and $v1, $a0, $v0
    bne $v1, $0, set_red

    addi $v0, $0, 2
    and $v1, $a0, $v0
    bne $v1, $0, set_pink

    addi $v0, $0, 1
    and $v1, $a0, $v0
    bne $v1, $0, set_white
    j color_ready

set_white:
    addi $t2, $0, 1
    j color_ready

set_pink:
    addi $t2, $0, 2
    j color_ready

set_red:
    addi $t2, $0, 3
    j color_ready

set_orange:
    addi $t2, $0, 4
    j color_ready

set_yellow:
    addi $t2, $0, 5
    j color_ready

set_green:
    addi $t2, $0, 6
    j color_ready

set_blue:
    addi $t2, $0, 7
    j color_ready

set_purple:
    addi $t2, $0, 8
    j color_ready

set_brown:
    addi $t2, $0, 9
    j color_ready

set_black:
    addi $t2, $0, 10

color_ready:
    sw $t2, 0($a2)
    bne $t5, $0, count_frame
    bne $t2, $0, start_draw
    j count_frame

start_draw:
    addi $t4, $0, 1

count_frame:
    addi $t9, $t9, 1
    blt $t9, $fp, after_moves
    addi $t9, $0, 0

    lw $a0, 0($s5)
    bne $a0, $0, try_up

check_down:
    lw $a0, 0($s6)
    bne $a0, $0, try_down

check_left:
    lw $a0, 0($s7)
    bne $a0, $0, try_left

check_right:
    lw $a0, 0($t0)
    bne $a0, $0, try_right
    j after_moves

try_up:
    bne $s1, $0, do_up
    j check_down

do_up:
    addi $s1, $s1, -1
    sub $s2, $s2, $t3
    addi $t4, $0, 1
    j check_down

try_down:
    blt $s1, $gp, do_down
    j check_left

do_down:
    addi $s1, $s1, 1
    add $s2, $s2, $t3
    addi $t4, $0, 1
    j check_left

try_left:
    bne $s0, $0, do_left
    j check_right

do_left:
    addi $s0, $s0, -1
    addi $s2, $s2, -1
    addi $t4, $0, 1
    j check_right

try_right:
    blt $s0, $sp, do_right
    j after_moves

do_right:
    addi $s0, $s0, 1
    addi $s2, $s2, 1
    addi $t4, $0, 1

after_moves:
    bne $t4, $0, do_paint
    j loop_wait

do_paint:
    sw $s0, 0($a3)
    sw $s1, 1($a3)
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
    addi $t9, $0, 0
    addi $t2, $0, 0
    sw $s0, 0($a3)
    sw $s1, 1($a3)
    sw $t2, 0($a2)
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
# 4104: SW[9:0], color select
# 4105: LD17 RGB color code
# 8192 + n: canvas cell n, 0 <= n < 4800
