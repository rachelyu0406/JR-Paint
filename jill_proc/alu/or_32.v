module or_32(out, A, B);

    input [31:0] A, B;
    genvar i;
    output [31:0] out;

    for (i = 0; i < 32; i = i + 1) begin
        or(out[i], A[i], B[i]);
    end

endmodule