module not_32(out, A);

    input [31:0] A;
    genvar i;
    output [31:0] out;

    for (i = 0; i < 32; i = i + 1) begin
        not(out[i], A[i]);
    end

endmodule