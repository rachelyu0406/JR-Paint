module register #(parameter WIDTH = 32)(out, d, clk, resetn, write_en);

    input clk, resetn, write_en;
    input [WIDTH-1:0] d;
    output [WIDTH-1:0] out;

    genvar i;
    generate
        for(i=0; i<WIDTH; i=i+1) begin : loop1
        dffe_ref a_dff(.q(out[i]), .d(d[i]), .clk(clk), .en(write_en), .clr(resetn));
        end
    endgenerate
endmodule