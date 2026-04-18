main:
    addi $s0, $0, 40        # x position
    addi $s1, $0, 30        # y position
    addi $s2, $0, 2440      # cell index = 30*80 + 40
    addi $s3, $0, 0         # last frame toggle
    addi $s4, $0, 8192      # canvas MMIO base
    addi $s5, $0, 0         # mouse x remainder
    addi $s6, $0, 0         # mouse y remainder
    addi $s7, $0, 0         # current mouse buttons
    addi $t0, $0, 4099      # mouse packet ready / ack MMIO
    addi $t1, $0, 4100      # frame-toggle MMIO
    addi $a3, $0, 4101      # cursor x MMIO
    addi $t7, $0, 4103      # BTNC MMIO
    addi $a1, $0, 4104      # switch MMIO
    addi $a2, $0, 4105      # LED17 MMIO
    addi $ra, $0, 4106      # pen size MMIO
    addi $t2, $0, 0         # current draw color = none
    addi $k0, $0, 1         # current pen size = 0.2
    addi $t3, $0, 80        # one canvas row
    addi $t8, $0, 4800      # total canvas cells
    addi $gp, $0, 58        # y must stay < 58 to move down
    addi $sp, $0, 78        # x must stay < 78 to move right

    sw $s0, 0($a3)
    sw $s1, 1($a3)
    sw $t2, 0($a2)
    sw $k0, 0($ra)
    sw $0, 0($0)
    sw $0, 1($0)

loop_wait:
    lw $a0, 0($t0)
    bne $a0, $0, frame_ready
    lw $a0, 0($t1)
    bne $a0, $s3, frame_ready
    j loop_wait

frame_ready:
    lw $a0, 0($t1)
    add $s3, $a0, $0
    lw $a0, 0($t7)
    bne $a0, $0, do_clear

    addi $a1, $0, 4104
    addi $a2, $0, 4105
    lw $a0, 0($a1)
    addi $v0, $0, 1023
    and $t6, $a0, $v0
    lw $t4, 0($0)
    lw $t5, 1($0)

    addi $v0, $0, 1
    and $v1, $t6, $v0
    bne $v1, $0, white_rise_prev
    j pink_rise
white_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, pink_rise
    addi $t5, $t5, 1
    sw $t5, 2($0)

pink_rise:
    addi $v0, $0, 2
    and $v1, $t6, $v0
    bne $v1, $0, pink_rise_prev
    j red_rise
pink_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, red_rise
    addi $t5, $t5, 1
    sw $t5, 3($0)

red_rise:
    addi $v0, $0, 4
    and $v1, $t6, $v0
    bne $v1, $0, red_rise_prev
    j orange_rise
red_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, orange_rise
    addi $t5, $t5, 1
    sw $t5, 4($0)

orange_rise:
    addi $v0, $0, 8
    and $v1, $t6, $v0
    bne $v1, $0, orange_rise_prev
    j yellow_rise
orange_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, yellow_rise
    addi $t5, $t5, 1
    sw $t5, 5($0)

yellow_rise:
    addi $v0, $0, 16
    and $v1, $t6, $v0
    bne $v1, $0, yellow_rise_prev
    j green_rise
yellow_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, green_rise
    addi $t5, $t5, 1
    sw $t5, 6($0)

green_rise:
    addi $v0, $0, 32
    and $v1, $t6, $v0
    bne $v1, $0, green_rise_prev
    j blue_rise
green_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, blue_rise
    addi $t5, $t5, 1
    sw $t5, 7($0)

blue_rise:
    addi $v0, $0, 64
    and $v1, $t6, $v0
    bne $v1, $0, blue_rise_prev
    j purple_rise
blue_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, purple_rise
    addi $t5, $t5, 1
    sw $t5, 8($0)

purple_rise:
    addi $v0, $0, 128
    and $v1, $t6, $v0
    bne $v1, $0, purple_rise_prev
    j brown_rise
purple_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, brown_rise
    addi $t5, $t5, 1
    sw $t5, 9($0)

brown_rise:
    addi $v0, $0, 256
    and $v1, $t6, $v0
    bne $v1, $0, brown_rise_prev
    j black_rise
brown_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, black_rise
    addi $t5, $t5, 1
    sw $t5, 10($0)

black_rise:
    addi $v0, $0, 512
    and $v1, $t6, $v0
    bne $v1, $0, black_rise_prev
    j choose_color
black_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, choose_color
    addi $t5, $t5, 1
    sw $t5, 11($0)

choose_color:
    sw $t6, 0($0)
    sw $t5, 1($0)
    addi $t2, $0, 0
    addi $k1, $0, 0

    addi $v0, $0, 1
    and $v1, $t6, $v0
    bne $v1, $0, white_pick_check
    j pink_pick
white_pick_check:
    lw $v0, 2($0)
    blt $k1, $v0, white_pick_set
    j pink_pick
white_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 1

pink_pick:
    addi $v0, $0, 2
    and $v1, $t6, $v0
    bne $v1, $0, pink_pick_check
    j red_pick
pink_pick_check:
    lw $v0, 3($0)
    blt $k1, $v0, pink_pick_set
    j red_pick
pink_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 2

red_pick:
    addi $v0, $0, 4
    and $v1, $t6, $v0
    bne $v1, $0, red_pick_check
    j orange_pick
red_pick_check:
    lw $v0, 4($0)
    blt $k1, $v0, red_pick_set
    j orange_pick
red_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 3

orange_pick:
    addi $v0, $0, 8
    and $v1, $t6, $v0
    bne $v1, $0, orange_pick_check
    j yellow_pick
orange_pick_check:
    lw $v0, 5($0)
    blt $k1, $v0, orange_pick_set
    j yellow_pick
orange_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 4

yellow_pick:
    addi $v0, $0, 16
    and $v1, $t6, $v0
    bne $v1, $0, yellow_pick_check
    j green_pick
yellow_pick_check:
    lw $v0, 6($0)
    blt $k1, $v0, yellow_pick_set
    j green_pick
yellow_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 5

green_pick:
    addi $v0, $0, 32
    and $v1, $t6, $v0
    bne $v1, $0, green_pick_check
    j blue_pick
green_pick_check:
    lw $v0, 7($0)
    blt $k1, $v0, green_pick_set
    j blue_pick
green_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 6

blue_pick:
    addi $v0, $0, 64
    and $v1, $t6, $v0
    bne $v1, $0, blue_pick_check
    j purple_pick
blue_pick_check:
    lw $v0, 8($0)
    blt $k1, $v0, blue_pick_set
    j purple_pick
blue_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 7

purple_pick:
    addi $v0, $0, 128
    and $v1, $t6, $v0
    bne $v1, $0, purple_pick_check
    j brown_pick
purple_pick_check:
    lw $v0, 9($0)
    blt $k1, $v0, purple_pick_set
    j brown_pick
purple_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 8

brown_pick:
    addi $v0, $0, 256
    and $v1, $t6, $v0
    bne $v1, $0, brown_pick_check
    j black_pick
brown_pick_check:
    lw $v0, 10($0)
    blt $k1, $v0, brown_pick_set
    j black_pick
brown_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 9

black_pick:
    addi $v0, $0, 512
    and $v1, $t6, $v0
    bne $v1, $0, black_pick_check
    j color_ready
black_pick_check:
    lw $v0, 11($0)
    blt $k1, $v0, black_pick_set
    j color_ready
black_pick_set:
    addi $t2, $0, 10

color_ready:
    addi $k0, $0, 1

    addi $v0, $0, 16384
    and $v1, $a0, $v0
    bne $v1, $0, set_size_1

    addi $v0, $0, 8192
    and $v1, $a0, $v0
    bne $v1, $0, set_size_08

    addi $v0, $0, 4096
    and $v1, $a0, $v0
    bne $v1, $0, set_size_06

    addi $v0, $0, 2048
    and $v1, $a0, $v0
    bne $v1, $0, set_size_04

    addi $v0, $0, 1024
    and $v1, $a0, $v0
    bne $v1, $0, set_size_02
    j pen_ready

set_size_02:
    addi $k0, $0, 1
    j pen_ready

set_size_04:
    addi $k0, $0, 2
    j pen_ready

set_size_06:
    addi $k0, $0, 3
    j pen_ready

set_size_08:
    addi $k0, $0, 4
    j pen_ready

set_size_1:
    addi $k0, $0, 5

pen_ready:
    sw $t2, 0($a2)
    sw $k0, 0($ra)

    addi $a0, $0, 4098
    lw $s7, 0($a0)
    addi $v0, $0, 4
    and $v1, $s7, $v0
    bne $v1, $0, do_clear

    addi $t4, $0, 0         # cursor update needed
    addi $t5, $0, 0         # paint enabled

    addi $v0, $0, 1
    and $v1, $s7, $v0
    bne $v1, $0, maybe_draw
    j read_mouse

maybe_draw:
    bne $t2, $0, enable_draw
    j read_mouse

enable_draw:
    addi $t4, $0, 1
    addi $t5, $0, 1

read_mouse:
    lw $a0, 0($t0)
    bne $a0, $0, have_mouse
    addi $v0, $0, 0
    addi $v1, $0, 0
    j move_up_check

have_mouse:
    addi $a0, $0, 4096
    lw $v0, 0($a0)
    add $s5, $s5, $v0
    addi $a0, $0, 4097
    lw $v1, 0($a0)
    add $s6, $s6, $v1
    addi $a0, $0, 4098
    lw $s7, 0($a0)
    sw $0, 0($t0)

move_up_check:
    addi $a0, $0, 19
    blt $a0, $s6, try_up
    j move_down_check

try_up:
    bne $s1, $0, do_up
    j move_down_check

do_up:
    addi $s1, $s1, -1
    sub $s2, $s2, $t3
    addi $s6, $s6, -20
    addi $t4, $0, 1
    j move_up_check

move_down_check:
    addi $a0, $0, -19
    blt $s6, $a0, try_down
    j move_right_check

try_down:
    blt $s1, $gp, do_down
    j move_right_check

do_down:
    addi $s1, $s1, 1
    add $s2, $s2, $t3
    addi $s6, $s6, 20
    addi $t4, $0, 1
    j move_down_check

move_right_check:
    addi $a0, $0, 19
    blt $a0, $s5, try_right
    j move_left_check

try_right:
    blt $s0, $sp, do_right
    j move_left_check

do_right:
    addi $s0, $s0, 1
    addi $s2, $s2, 1
    addi $s5, $s5, -20
    addi $t4, $0, 1
    j move_right_check

move_left_check:
    addi $a0, $0, -19
    blt $s5, $a0, try_left
    j after_moves

try_left:
    bne $s0, $0, do_left
    j after_moves

do_left:
    addi $s0, $s0, -1
    addi $s2, $s2, -1
    addi $s5, $s5, 20
    addi $t4, $0, 1
    j move_left_check

after_moves:
    bne $t4, $0, do_paint
    j loop_wait

do_paint:
    sw $s0, 0($a3)
    sw $s1, 1($a3)
    bne $t5, $0, paint_cell
    j loop_wait

paint_cell:
    addi $k1, $k0, -1
    addi $v0, $s1, 0
    sub $v0, $v0, $k1
    addi $v1, $s1, 0
    add $v1, $v1, $k1
    addi $a0, $s2, 0
    sub $a0, $a0, $k1
    addi $a1, $k1, 0

prep_row:
    bne $a1, $0, prep_row_step
    j row_loop

prep_row_step:
    sub $a0, $a0, $t3
    addi $a1, $a1, -1
    j prep_row

row_loop:
    blt $v0, $0, next_row
    addi $a1, $0, 60
    blt $v0, $a1, row_in_range
    j next_row

row_in_range:
    addi $a1, $s0, 0
    sub $a1, $a1, $k1
    addi $a2, $s0, 0
    add $a2, $a2, $k1
    addi $t6, $a0, 0

col_loop:
    blt $a1, $0, skip_cell
    blt $a1, $t3, write_cell
    j skip_cell

write_cell:
    add $t4, $s4, $t6
    sw $t2, 0($t4)

skip_cell:
    addi $a1, $a1, 1
    addi $t6, $t6, 1
    blt $a2, $a1, next_row
    j col_loop

next_row:
    addi $v0, $v0, 1
    add $a0, $a0, $t3
    blt $v1, $v0, loop_wait
    j row_loop

do_clear:
    addi $s0, $0, 40
    addi $s1, $0, 30
    addi $s2, $0, 2440
    addi $s5, $0, 0
    addi $s6, $0, 0
    addi $s7, $0, 0
    addi $t2, $0, 0
    addi $k0, $0, 1
    addi $a2, $0, 4105
    sw $s0, 0($a3)
    sw $s1, 1($a3)
    sw $t2, 0($a2)
    sw $k0, 0($ra)
    sw $0, 0($t0)
    addi $a0, $0, 0

clear_loop:
    add $t6, $s4, $a0
    sw $0, 0($t6)
    addi $a0, $a0, 1
    blt $a0, $t8, clear_loop

clear_wait:
    lw $a0, 0($t7)
    bne $a0, $0, clear_wait
    j loop_wait

# MMIO map used by the top file:
# 4096: accumulated mouse dx
# 4097: accumulated mouse dy
# 4098: mouse buttons {middle,right,left}
# 4099: packet ready, write any value to clear dx/dy + ready
# 4100: frame toggle, flips once per screen refresh
# 4101: live cursor x position in grid cells
# 4102: live cursor y position in grid cells
# 4103: BTNC, clears the canvas and recenters the cursor
# 4104: SW[14:0], color + pen size select
# 4105: LD17 RGB color code
# 4106: current pen size code for DISP1
# 8192 + n: canvas cell n, 0 <= n < 4800
