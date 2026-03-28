module comp_8(EQ1, GT1, A, B, EQ0, GT0);
    input EQ1, GT1;
    input [7:0] A, B;
    output EQ0, GT0;

    wire[3:0] w, q;

    twobit_comparator highest2(EQ1, GT1, A[7:6], B[7:6], w[3], q[3]);
    twobit_comparator higher2(w[3], q[3], A[5:4], B[5:4], w[2], q[2]);
    twobit_comparator lower2(w[2], q[2], A[3:2], B[3:2], w[1], q[1]);
    twobit_comparator lowest2(w[1], q[1], A[1:0], B[1:0], EQ0, GT0);

endmodule