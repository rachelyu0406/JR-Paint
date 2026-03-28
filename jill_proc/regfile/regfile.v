module regfile(
    clock, ctrl_writeEnable, ctrl_reset, ctrl_writeReg,
    ctrl_readRegA, ctrl_readRegB, data_writeReg, data_readRegA,
    data_readRegB
);

    input clock, ctrl_writeEnable, ctrl_reset;
    input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
    input [31:0] data_writeReg;

    output [31:0] data_readRegA, data_readRegB;

    wire [31:0] q [0:31];  
    wire [31:0] rs1, rs2, rd;

    decoder decA(.out(rs1), .select(ctrl_readRegA), .enable(1'b1));
    decoder decB(.out(rs2), .select(ctrl_readRegB), .enable(1'b1));
    decoder decW(.out(rd),  .select(ctrl_writeReg), .enable(ctrl_writeEnable));

	//HARDWIRE reg0 TO 0
	assign q[0] = 32'b0;

    genvar i;

	//instantiation with write port
    generate
        for (i = 1; i < 32; i = i + 1) begin : regs
			//register(out, d, clk, resetn, write_en);
            register #(32) r(.out(q[i]), .d(data_writeReg), .clk(clock), .resetn(ctrl_reset), .write_en(rd[i]));
        end
    endgenerate

    // read port 1
    generate
        for (i = 0; i < 32; i = i + 1) begin : readA
            tristate #(32) ts1(.out(data_readRegA), .in(q[i]), .en(rs1[i]));
        end
    endgenerate

    // read port 2
    generate
        for (i = 0; i < 32; i = i + 1) begin : readB
            tristate #(32) ts2(.out(data_readRegB), .in(q[i]), .en(rs2[i]));
        end
    endgenerate

endmodule