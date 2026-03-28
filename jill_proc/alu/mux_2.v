module mux_2 #(parameter WIDTH = 32) (out, select, in0, in1);

output [WIDTH-1:0]out;
input [WIDTH-1:0]in1, in0;
input select;

assign out = select ? in1 : in0;
endmodule