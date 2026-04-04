# MMIO map
# 0 -> buttons    [bit0=U, bit1=D, bit2=L, bit3=R]
# 1 -> cursor x
# 2 -> cursor y
# 3 -> frame tick

addi $4,  $0, 24      # cursor x default
addi $5,  $0, 16      # cursor y default
addi $7,  $0, 49      # max x
addi $8,  $0, 33      # max y
addi $11, $0, 1       # up mask
addi $12, $0, 2       # down mask
addi $13, $0, 4       # left mask
addi $14, $0, 8       # right mask

sw   $4, 1($0)
sw   $5, 2($0)
lw   $2, 3($0)

main_wait:
lw   $3, 3($0)
bne  $3, $2, step
j    main_wait

step:
add  $2, $3, $0
lw   $1, 0($0)

and  $15, $1, $11
bne  $15, $0, do_up
j    check_down

do_up:
bne  $5, $0, up_ok
j    check_down

up_ok:
addi $5, $5, -1

check_down:
and  $15, $1, $12
bne  $15, $0, do_down
j    check_left

do_down:
bne  $5, $8, down_ok
j    check_left

down_ok:
addi $5, $5, 1

check_left:
and  $15, $1, $13
bne  $15, $0, do_left
j    check_right

do_left:
bne  $4, $0, left_ok
j    check_right

left_ok:
addi $4, $4, -1

check_right:
and  $15, $1, $14
bne  $15, $0, do_right
j    write_back

do_right:
bne  $4, $7, right_ok
j    write_back

right_ok:
addi $4, $4, 1

write_back:
sw   $4, 1($0)
sw   $5, 2($0)
j    main_wait