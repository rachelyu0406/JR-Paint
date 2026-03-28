module notEqual_32(isNotEqual, a, b);

    input  [31:0] a, b;
    output        isNotEqual;

    wire [31:0] x;
    wire [15:0] o1;
    wire [7:0]  o2;
    wire [3:0]  o3;
    wire [1:0]  o4;

    genvar i;

    generate
        for (i=0; i<32; i=i+1) begin : XORs
            xor (x[i], a[i], b[i]);
        end

        for (i=0; i<16; i=i+1) begin : L1
            or (o1[i], x[2*i], x[2*i+1]);
        end
        for (i=0; i<8; i=i+1) begin : L2
            or (o2[i], o1[2*i], o1[2*i+1]);
        end
        for (i=0; i<4; i=i+1) begin : L3
            or (o3[i], o2[2*i], o2[2*i+1]);
        end
        for (i=0; i<2; i=i+1) begin : L4
            or (o4[i], o3[2*i], o3[2*i+1]);
        end
    endgenerate

    or (isNotEqual, o4[0], o4[1]);

endmodule
