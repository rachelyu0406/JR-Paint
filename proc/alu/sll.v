module sll(out, a, shamt);

    input [31:0]a;
    input [4:0]shamt;

    output [31:0]out;

    wire[31:0] a1, a2, a4, a8;

    assign a1 = shamt[0] ? {a[30:0], 1'b0} : a;
    
    assign a2 = shamt[1] ? {a1[29:0], 2'b0} : a1;
    
    assign a4 = shamt[2] ? {a2[27:0], 4'b0} : a2;

    assign a8 = shamt[3] ? {a4[23:0], 8'b0} : a4;

    assign out = shamt[4] ? {a8[15:0], 16'b0} : a8;

endmodule