module tristate #(parameter WIDTH = 32) (out, in, en);

    input [WIDTH-1:0] in;
    input en;
    output [WIDTH-1:0] out;

    assign out = en ? in : {WIDTH{1'bz}};

endmodule