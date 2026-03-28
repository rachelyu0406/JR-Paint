module latch(clk, reset, enable, pc_in, pc_out, insn_in, insn_out, rs_din, rs_dout, rt_din, rt_dout, 
            rs_in, rs_out, rt_in, rt_out, rd_in, rd_out, shamt_in, shamt_out, imme_in, imme_out, 
            alu_in, alu_out, isNotEq_in, isNotEq_out, data_in, data_out, muldivRes_in, muldivRes_out, mulDivReady_in,
            mulDivReady_out, exception_in, exception_out, target_in, target_out);

input clk, reset, enable;
input[31:0] pc_in, insn_in, rs_din, rt_din, alu_in, data_in, muldivRes_in;
input[4:0] rs_in, rt_in, rd_in, shamt_in;
input[16:0] imme_in;
input isNotEq_in, mulDivReady_in, exception_in;
input [26:0] target_in;

output[31:0] pc_out, insn_out, rs_dout, rt_dout, alu_out, data_out, muldivRes_out;
output[4:0] rs_out, rt_out, rd_out, shamt_out;
output[16:0] imme_out;
output isNotEq_out, mulDivReady_out, exception_out;
output [26:0] target_out;


//(out, d, clk, resetn, write_en);
register #(.WIDTH(32)) pc(.out(pc_out), .d(pc_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(32)) insn(.out(insn_out), .d(insn_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(32)) rsd(.out(rs_dout), .d(rs_din), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(32)) rtd(.out(rt_dout), .d(rt_din), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(5)) rd(.out(rd_out), .d(rd_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(5)) rs(.out(rs_out), .d(rs_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(5)) rt(.out(rt_out), .d(rt_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(5)) shamt(.out(shamt_out), .d(shamt_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(17)) imme(.out(imme_out), .d(imme_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(32)) alu_o(.out(alu_out), .d(alu_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(32)) data_o(.out(data_out), .d(data_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(1)) notEq_o(.out(isNotEq_out), .d(isNotEq_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(32)) muldivL(.out(muldivRes_out), .d(muldivRes_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(1)) muldivR(.out(mulDivReady_out), .d(mulDivReady_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(1)) exception_o(.out(exception_out), .d(exception_in), .clk(clk), .resetn(reset), .write_en(enable));
register #(.WIDTH(27)) target(.out(target_out), .d(target_in), .clk(clk), .resetn(reset), .write_en(enable));

endmodule