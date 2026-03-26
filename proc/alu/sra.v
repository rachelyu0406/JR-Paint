module sra(out, a, shamt);

    input [31:0]a;
    input [4:0]shamt;

    output [31:0] out;

    wire[31:0] a1, a2, a4, a8;

    assign a1 = shamt[0] ? {{1{a[31]}}, a[31:1]} : a;

    assign a2 = shamt[1] ? {{2{a[31]}}, a1[31:2]} : a1;
    
    assign a4 = shamt[2] ? {{4{a[31]}}, a2[31:4]} : a2;

    assign a8 = shamt[3] ? {{8{a[31]}}, a4[31:8]} : a4;

    assign out = shamt[4] ? {{16{a[31]}}, a8[31:16]} : a8;

endmodule