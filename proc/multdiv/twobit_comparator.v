module twobit_comparator(EQ1, GT1, A, B, EQ0, GT0);
    input EQ1, GT1;
    input [1:0] A, B;
    output EQ0, GT0;

    wire eqn, gtn;
    wire eq_gtn, eqn_gt;
    wire b0n, b0;
    wire outEQ, outGT1, outGT2;

    not(eqn, EQ1);
    not(gtn, GT1);
    not(b0n, B[0]);
    assign b0 = B[0];

    and(eq_gtn, EQ1, gtn);
    and(eqn_gt, eqn, GT1);

    mux_8 #(1) eq(outEQ, {A[1], A[0], B[1]}, b0n, 1'b0, b0, 1'b0, 1'b0, b0n, 1'b0, b0);
    mux_8 #(1) gt(outGT1, {A[1], A[0], B[1]}, 1'b0, 1'b0, b0n, 1'b0, 1'b1, 1'b0, 1'b1, b0n);

    and(EQ0, eq_gtn, outEQ);
    and(outGT2, eq_gtn, outGT1);
    or(GT0, eqn_gt, outGT2);

endmodule