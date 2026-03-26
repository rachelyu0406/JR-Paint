module comparator_32(A, B, EQ0, GT0);

    input [31:0] A, B;
    output EQ0, GT0;

    wire[3:0] w, q;

    comp_8 highest8(1'b1, 1'b0, A[31:24], B[31:24], w[3], q[3]);
    comp_8 higher8(w[3], q[3], A[23:16], B[23:16], w[2], q[2]);
    comp_8 lower8(w[2], q[2], A[15:8], B[15:8], w[1], q[1]);
    comp_8 lowest8(w[1], q[1], A[7:0], B[7:0], EQ0, GT0);

endmodule