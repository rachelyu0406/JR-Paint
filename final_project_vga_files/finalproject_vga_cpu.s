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
    addi $t2, $0, 1         # pixel value to write
    addi $t3, $0, 80        # one canvas row
    addi $t4, $0, 81        # one row plus one column
    addi $t5, $0, 58        # y must stay < 58 to move down
    addi $t6, $0, 78        # x must stay < 78 to move right

    jal paint_current

loop_wait:
    lw $a0, 0($t1)
    bne $a0, $s3, frame_ready
    j loop_wait

frame_ready:
    add $s3, $a0, $0
    addi $a1, $0, 0         # moved flag

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
    bne $a1, $0, do_paint
    j loop_wait

try_up:
    bne $s1, $0, do_up
    j check_down

do_up:
    addi $s1, $s1, -1
    sub $s2, $s2, $t3
    addi $a1, $0, 1
    j check_horizontal

try_down:
    blt $s1, $t5, do_down
    j check_horizontal

do_down:
    addi $s1, $s1, 1
    add $s2, $s2, $t3
    addi $a1, $0, 1
    j check_horizontal

try_left:
    bne $s0, $0, do_left
    j check_right

do_left:
    addi $s0, $s0, -1
    addi $s2, $s2, -1
    addi $a1, $0, 1
    j after_moves

try_right:
    blt $s0, $t6, do_right
    j after_moves

do_right:
    addi $s0, $s0, 1
    addi $s2, $s2, 1
    addi $a1, $0, 1

do_paint:
    jal paint_current
    j loop_wait

paint_current:
    add $a0, $s4, $s2
    sw $t2, 0($a0)
    addi $a2, $a0, 1
    sw $t2, 0($a2)
    add $a2, $a0, $t3
    sw $t2, 0($a2)
    add $a2, $a0, $t4
    sw $t2, 0($a2)
    jr $ra

# MMIO map used by the top file:
# 4096: BTNU
# 4097: BTND
# 4098: BTNL
# 4099: BTNR
# 4100: frame toggle, flips once per screen refresh
# 8192 + n: canvas cell n, 0 <= n < 4800
