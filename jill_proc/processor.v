/**
 * READ THIS DESCRIPTION!
 *
 * This is your processor module that will contain the bulk of your code submission. You are to implement
 * a 5-stage pipelined processor in this module, accounting for hazards and implementing bypasses as
 * necessary.
 *
 * Ultimately, your processor will be tested by a master skeleton, so the
 * testbench can see which controls signal you active when. Therefore, there needs to be a way to
 * "inject" imem, dmem, and regfile interfaces from some external controller module. The skeleton
 * file, Wrapper.v, acts as a small wrapper around your processor for this purpose. Refer to Wrapper.v
 * for more details.
 *
 * As a result, this module will NOT contain the RegFile nor the memory modules. Study the inputs 
 * very carefully - the RegFile-related I/Os are merely signals to be sent to the RegFile instantiated
 * in your Wrapper module. This is the same for your memory elements. 
 *
 *
 */
module processor(
    // Control signals
    clock,                          // I: The master clock
    reset,                          // I: A reset signal

    // Imem
    address_imem,                   // O: The address of the data to get from imem
    q_imem,                         // I: The data from imem

    // Dmem
    address_dmem,                   // O: The address of the data to get or put from/to dmem
    data,                           // O: The data to write to dmem
    wren,                           // O: Write enable for dmem
    q_dmem,                         // I: The data from dmem

    // Regfile
    ctrl_writeEnable,               // O: Write enable for RegFile
    ctrl_writeReg,                  // O: Register to write to in RegFile
    ctrl_readRegA,                  // O: Register to read from port A of RegFile
    ctrl_readRegB,                  // O: Register to read from port B of RegFile
    data_writeReg,                  // O: Data to write to for RegFile
    data_readRegA,                  // I: Data from port A of RegFile
    data_readRegB                   // I: Data from port B of RegFile
	 
	);

	// Control signals
	input clock, reset;
	
	// Imem from ROM
    output [31:0] address_imem;
	input [31:0] q_imem;

	// Dmem from/to RAM
	output [31:0] address_dmem, data;
	output wren;
	input [31:0] q_dmem;

	// Regfile
	output ctrl_writeEnable;
	output [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	output [31:0] data_writeReg;
	input [31:0] data_readRegA, data_readRegB;

    // ================FETCH STAGE=================== //

    wire dx_fd_latchEnable, xm_latchEnable;
    assign dx_fd_latchEnable = latchEnable & ~lw_hazard_d;

    //module latch(clk, reset, enable, pc_in, pc_out, insn_in, insn_out, rs_din, rs_dout, rt_din, rt_dout, rs_in, rs_out, rt_in, rt_out, rd_in, rd_out, shamt_in, shamt_out, imme_in, imme_out, alu_in, alu_out);
    wire[31:0] processor_pc_in_plus1, processor_pc_in_jr, processor_pc_in, processor_pc_in_j, processor_pc_in_j2, 
    processor_pc_in_bne, processor_pc_in_blt, processor_pc_out, processor_pc_in_bex;
    wire[26:0] T;

    wire latchEnable;

    //(out, d, clk, resetn, write_en);
    register #(.WIDTH(32)) PC(.clk(~clock), .resetn(reset), .write_en(dx_fd_latchEnable), .d(processor_pc_in), .out(processor_pc_out));
    //cla_level2(a, b, s, cin, cout, last4);
    cla_level2 pcCounter(.a(processor_pc_out), .b(32'b1), .s(processor_pc_in_plus1), .cin(1'b0));

    assign address_imem = processor_pc_out;
    assign T = q_imem[26:0];

    wire isJ;
    assign isJ = q_imem[31:27] == 5'b00001;

    //jump is always last

    assign processor_pc_in_j = isJ ? {5'b00000,T} : processor_pc_in_plus1;
    
    assign processor_pc_in_bex = bexTaken ? {5'b0, fd_insn_out[26:0]} : processor_pc_in_j;

    assign processor_pc_in_bne = BNETaken ? BNEResult : processor_pc_in_bex;

    assign processor_pc_in_blt = BLTTaken ? BranchResult : processor_pc_in_bne;

    assign processor_pc_in_j2 = isJal ? {5'b0, dx_insn_out[26:0]} : processor_pc_in_blt;

    assign processor_pc_in = isJr ? jr_reg_bypassed: processor_pc_in_j2;

    //DONT FLUSH JJJSSSS LETS GOOO
    wire shouldFlush_f, shouldFlush_fd;
    assign shouldFlush_f = BNETaken | BLTTaken | isJr | isJal | bexTaken;
    assign shouldFlush_fd = BLTTaken | isJr | isJal;

    wire[31:0] fd_insn_in;

    assign fd_insn_in = (shouldFlush_f) ? 32'b0 : q_imem;

    // Latch instruction from imem
    wire [31:0] fd_insn_out;
    wire[31:0] fd_pc_out;
    latch FD_INSN(.clk(~clock), .reset(reset), .enable(dx_fd_latchEnable), .pc_in(processor_pc_in_plus1), .pc_out(fd_pc_out), 
    .insn_in(fd_insn_in), .insn_out(fd_insn_out)); 

    // ================DECODE STAGE================== //

    wire [4:0] fd_opcode = fd_insn_out[31:27];
    wire RTypeD;
    assign RTypeD = ~(|fd_opcode);

    wire isAddiD;
    assign isAddiD = (fd_opcode == 5'b00101);

    wire isBLTD, d_isBex;

    assign isBLTD = (fd_opcode == 5'b00110);

    assign d_isBex = (fd_opcode == 5'b10110);

    wire isLWD;

    assign isLWD = (fd_opcode == 5'b01000);

    //note: if blt we need to put reg a = rD and reg b = Rs because theyre weird

    // Decode RS register
    assign ctrl_readRegA = isBNE ? fd_insn_out[26:22] : (d_isBex ? 5'd30 : (isBLTD ? fd_insn_out[26:22] : fd_insn_out[21:17]));
    //Decode RT register and its not RType its i type so we might need rd
    assign ctrl_readRegB = isBNE ? fd_insn_out[21:17] : (isBLTD ? fd_insn_out[21:17] : (RTypeD ? fd_insn_out[16:12] : fd_insn_out[26:22]));
    //Decode RD register
    wire[4:0] fd_rd;
    assign fd_rd = fd_insn_out[26:22];
    //Decode Immediate
    wire[16:0] imme;
    assign imme = fd_insn_out[16:0];
    //Decode Shamt
    wire[4:0] shamt;
    assign shamt = fd_insn_out[11:7];

    wire[26:0] target;
    assign target = fd_insn_out[26:0];

    //x -> d sw bypass logic for rd
    //this section is super scuffed and i think i coded for the same thing twice
    wire isSWD, sw_bypassInsn_x_rd, sw_bypass_x_rd;

    assign isSWD = (fd_opcode == 5'b00111);

    assign sw_bypassInsn_x_rd = (RTypeX | opcodeX == 5'b00101 | opcodeX == 5'b01000);

    assign sw_bypass_x_rd = isSWD & (ctrl_readRegB == dx_rd_out) & sw_bypassInsn_x_rd & (dx_insn_out != 32'b0);

    wire[31:0] sw_data_bypassed_readRegB;
    assign sw_data_bypassed_readRegB = sw_bypass_x_rd ? alu_out_orMD : data_readRegB;

    wire sw_bypass_x_rs;
    assign sw_bypass_x_rs = isSWD & (ctrl_readRegA == dx_rd_out) & sw_bypassInsn_x_rd & (dx_insn_out != 32'b0);

    wire[31:0] sw_addr_bypassed_readRegA;
    assign sw_addr_bypassed_readRegA = sw_bypass_x_rs ? alu_out_orMD : data_readRegA;



    wire bexTaken;

    assign bexTaken = x_isSetx ? (d_isBex & ({5'd0 ,dx_target_out} != 32'b0)) : 
                     (m_isSetx ? (d_isBex & ({5'd0 ,xm_target_out} != 32'b0)) : 
                     //if the datawrite reg is not 0, basically an exception occured 
                     (w_isSetx ? (d_isBex & (data_writeReg != 32'b0)) : 
                     (d_isBex & (data_readRegA != 32'b0))));

    wire isBNE, BNETaken; 
    wire[31:0] BNEResult;
    wire[31:0] bne_regA_bypassed, bne_regB_bypassed;
    wire bne_bypass_m_regA, bne_bypass_m_regB, bne_bypass_LW_regA, bne_bypass_LW_regB; 
    wire bne_bypass_w_regA, bne_bypass_w_regB;

    assign isBNE = (fd_opcode == 5'b00010);

    wire lw_in_x;
    assign lw_in_x = (dx_insn_out[31:27] == 5'b01000);

    //where LW -> SW rs bypassing lmao holy hardcode
    wire LW_SW_rs;

    assign LW_SW_rs = (isSWD & (dx_rd_out == ctrl_readRegA));

    //where LW -> LW rd -> rs
    wire LW_LW_rd_rs;

    assign LW_LW_rd_rs = (isLWD & (dx_rd_out == ctrl_readRegA));

    wire lw_hazard_d;
    assign lw_hazard_d = (lw_in_x & ((ctrl_readRegA == dx_rd_out) | (ctrl_readRegB == dx_rd_out)) 
                        & (isBNE | RTypeD | isAddiD | isBLTD | LW_SW_rs | LW_LW_rd_rs));

    assign bne_bypass_m_regA = (ctrl_readRegA == xm_rd_out) & (RTypeM | OpcodeM == 5'b00101) & (xm_insn_out != 32'b0);
    assign bne_bypass_m_regB = (ctrl_readRegB == xm_rd_out) & (RTypeM | OpcodeM == 5'b00101) & (xm_insn_out != 32'b0);
    assign bne_bypass_LW_regA = (ctrl_readRegA == xm_rd_out) & (OpcodeM == 5'b01000) & (xm_insn_out != 32'b0);
    assign bne_bypass_LW_regB = (ctrl_readRegB == xm_rd_out) & (OpcodeM == 5'b01000) & (xm_insn_out != 32'b0);

    assign bne_bypass_w_regA = (ctrl_readRegA == ctrl_writeReg) & (RTypeW | mw_Opcode == 5'b00101) & (xm_insn_out != 32'b0);
    assign bne_bypass_w_regB = (ctrl_readRegB == ctrl_writeReg) & (RTypeW | mw_Opcode == 5'b00101) & (xm_insn_out != 32'b0);

    assign bne_regA_bypassed = bne_bypass_LW_regA ? q_dmem : 
                            (bne_bypass_m_regA ? xm_alu_out : 
                           (bne_bypass_w_regA ? data_writeReg : data_readRegA));

    assign bne_regB_bypassed = bne_bypass_LW_regB ? q_dmem : 
                            (bne_bypass_m_regB ? xm_alu_out : 
                           (bne_bypass_w_regB ? data_writeReg : data_readRegB));

    assign BNETaken = (isBNE & (bne_regA_bypassed != bne_regB_bypassed));

    cla_level2 BNETarget(.a(fd_pc_out), .b({{15{imme[16]}}, imme}), .s(BNEResult), .cin(1'b0), .cout(), .last4());

    // DX Latch 
    wire [31:0] dx_insn_out, dx_pc_out, dx_data_readRegA, dx_data_readRegB;
    wire[4:0] dx_rs_out, dx_rt_out, dx_rd_out, dx_shamt_out;
    wire[16:0] dx_imme_out;
    wire[26:0] dx_target_out;

    wire[31:0] dx_insn_in;
    assign dx_insn_in = (shouldFlush_fd | lw_hazard_d) ? 32'b0 : fd_insn_out;

    latch DX(.clk(~clock), .reset(reset), .enable(latchEnable), .pc_in(fd_pc_out), .pc_out(dx_pc_out), .insn_in(dx_insn_in), 
    .insn_out(dx_insn_out), .rs_din(sw_addr_bypassed_readRegA), .rs_dout(dx_data_readRegA), .rt_din(sw_data_bypassed_readRegB), .rt_dout(dx_data_readRegB), 
    .rs_in(ctrl_readRegA), .rs_out(dx_rs_out), .rt_in(ctrl_readRegB), .rt_out(dx_rt_out), .rd_in(fd_rd), .rd_out(dx_rd_out), 
    .shamt_in(shamt), .shamt_out(dx_shamt_out), .imme_in(imme), .imme_out(dx_imme_out), .target_in(target), .target_out(dx_target_out));

    // ================EXECUTE STAGE================= //

    //FLUSHHHHHHHH!!!! FOR JUMPS AND BRANCEHS IF UR TAKING THE BRANCH OR JR OR JAL 

    //but gonna have to change later to some fast branch or sum
    //also there was something on the slides that says that bne should be moved to decode stage or sum (i guess this is what fast branching is)
    //darn i didnt need to do allat

    wire isNotEqX, isJr, isJal, isBLT, BLTTaken, isBranch, x_isSetx, isSW;
    wire isLess;
    wire over, xm_over;
    wire [31:0] alu_out, BranchResult;
    wire[31:0] into_alu_B, into_alu_B_bp, into_alu_A_bp;
    wire RTypeX;
    wire[4:0] opcodeX;

    assign opcodeX = dx_insn_out[31:27];

    assign x_isSetx = (opcodeX == 5'b10101);

    assign RTypeX = ~(|opcodeX);

    assign isJr = (opcodeX == 5'b00100);

    assign isJal = (opcodeX == 5'b00011);

    assign isBLT = (opcodeX == 5'b00110);

    assign BLTTaken = (isBLT & isLess);

    assign isBranch = isBLT;

    //lw -> sw bypass logic
    assign isSW = (opcodeX == 5'b00111);

    wire sw_bypass_m_rd_lw, sw_bypass_m_rd_alu, sw_bypass_w_rd;
    wire[31:0] dx_bypass_data_readRegB;

    // Separate LW vs ALU bypass from M stage
    assign sw_bypass_m_rd_lw = isSW & (dx_rd_out == xm_rd_out) & (OpcodeM == 5'b01000) & (xm_insn_out != 32'b0);    
    assign sw_bypass_m_rd_alu = isSW & (dx_rd_out == xm_rd_out) & (RTypeM | OpcodeM == 5'b00101) & (xm_insn_out != 32'b0);
    assign sw_bypass_w_rd = isSW & (dx_rd_out == ctrl_writeReg) & bypassInsn_w_rt & (xm_insn_out != 32'b0);

    assign dx_bypass_data_readRegB = sw_bypass_m_rd_lw ? q_dmem : 
                                  (sw_bypass_m_rd_alu ? xm_alu_out :
                                  (sw_bypass_w_rd ? data_writeReg : dx_data_readRegB));

    wire sw_bypass_m_rs_lw, sw_bypass_m_rs_alu, sw_bypass_w_rs;
    wire[31:0] dx_bypass_data_readRegA;

    assign sw_bypass_m_rs_lw = isSW & (dx_rs_out == xm_rd_out) & (OpcodeM == 5'b01000) & (xm_insn_out != 32'b0);    
    assign sw_bypass_m_rs_alu = isSW & (dx_rs_out == xm_rd_out) & (RTypeM | OpcodeM == 5'b00101) & (xm_insn_out != 32'b0);
    assign sw_bypass_w_rs = isSW & (dx_rs_out == ctrl_writeReg) & bypassInsn_w_rs & (xm_insn_out != 32'b0);

    assign dx_bypass_data_readRegA = sw_bypass_m_rs_lw ? q_dmem : 
                                  (sw_bypass_m_rs_alu ? xm_alu_out :
                                  (sw_bypass_w_rs ? data_writeReg : dx_data_readRegA));



    wire jr_bypass_m_regA, jr_bypass_m_regB, jr_bypass_LW_regA, x_bypass_LW_regA, 
    x_bypass_LW_regB, jr_bypass_w_regA, jr_bypass_w_regB;

    //jr only takes regB because of how i handled that sht in decode
    assign jr_bypass_m_regB = (dx_rt_out == xm_rd_out) & bypassInsn_m_rt & (xm_insn_out != 32'b0);
    assign jr_bypass_w_regB = (dx_rt_out == ctrl_writeReg) & bypassInsn_w_rt & (xm_insn_out != 32'b0);

    assign x_bypass_LW_regB = (dx_rt_out == xm_rd_out) & (OpcodeM == 5'b01000) & (xm_insn_out != 32'b0);
    assign x_bypass_LW_regA = (dx_rs_out == xm_rd_out) & (OpcodeM == 5'b01000) & (xm_insn_out != 32'b0);

    wire[31:0] jr_reg_bypassed;
    assign jr_reg_bypassed = x_bypass_LW_regB ? q_dmem : 
                            (jr_bypass_m_regB ? xm_alu_out : 
                           (jr_bypass_w_regB ? data_writeReg : dx_data_readRegB));

    wire x_bypass_w_rs, x_bypass_m_rs, x_bypass_p_rs;
    wire bypassInsn_w_rs, bypassInsn_m_rs, bypassInsn_p_rs;

    assign bypassInsn_w_rs = (RTypeW | mw_Opcode == 5'b00101 | mw_Opcode == 5'b01000);

    assign bypassInsn_m_rs = (RTypeM | OpcodeM == 5'b00101);

    // assign bypassInsn_p_rs = (RTypeP | pw_alu_op == 5'b00101);

    assign x_bypass_w_rs = (dx_rs_out == ctrl_writeReg) & bypassInsn_w_rs & (ctrl_writeReg != 5'd0);

    assign x_bypass_m_rs = (dx_rs_out == xm_over_rd_out) & bypassInsn_m_rs & (xm_insn_out != 32'b0) & 
                            (xm_over_rd_out != 5'd0);

    // assign x_bypass_p_rs = (dx_rs_out == ctrl_writeReg) & bypassInsn_p_rs & multDivReady_out;

    wire x_bypass_w_rt, x_bypass_m_rt, x_bypass_p_rt;
    wire bypassInsn_w_rt, bypassInsn_m_rt, bypassInsn_p_rt;

    assign bypassInsn_w_rt = (RTypeW | mw_Opcode == 5'b00101 | mw_Opcode == 5'b01000);

    assign bypassInsn_m_rt = (RTypeM | OpcodeM == 5'b00101);

    //assign bypassInsn_p_rt = (RTypeP | pw_alu_op == 5'b00101);

    //I FINALLY CAUGHT THIS SUCKER ITS BECAUSE I DONT WANT TO BYPASS TO RT IF WE ARE NOT doing rtype
    wire x_alu_uses_regB = RTypeX | isBranch;

    assign x_bypass_w_rt = (dx_rt_out == ctrl_writeReg) & x_alu_uses_regB
                            & bypassInsn_w_rt & (ctrl_writeReg != 5'd0);

    assign x_bypass_m_rt = (dx_rt_out == xm_over_rd_out) & bypassInsn_m_rt & (xm_insn_out != 32'b0) 
                            & x_alu_uses_regB & (xm_over_rd_out != 5'd0);

    // assign x_bypass_p_rt = (dx_rt_out == ctrl_writeReg) & bypassInsn_p_rt & multDivReady_out;

    assign into_alu_A_bp = 
                    ((x_bypass_m_rs ? xm_over_alu_out : 
                    (x_bypass_w_rs ? data_writeReg : dx_data_readRegA)));

    //if we are doing branch not equal
    assign into_alu_B = isBranch ? dx_data_readRegB : (RTypeX ? dx_data_readRegB : {{15{dx_imme_out[16]}}, dx_imme_out});

    assign into_alu_B_bp = 
                    (x_bypass_m_rt ? xm_over_alu_out : 
                    (x_bypass_w_rt ? data_writeReg : into_alu_B));

    wire[4:0] alu_op;

    assign alu_op = RTypeX ? dx_insn_out[6:2] : 5'b0;

    // Use ALU to compute result
    alu ALU(.data_operandA(into_alu_A_bp), .data_operandB(into_alu_B_bp), .ctrl_ALUopcode(alu_op), .ctrl_shiftamt(dx_shamt_out), .data_result(alu_out), .isNotEqual(isNotEqX), .isLessThan(isLess), .overflow(over));

    //cla_level2(a, b, s, cin, cout, last4);
    cla_level2 branchTarget(.a(dx_pc_out), .b({{15{dx_imme_out[16]}}, dx_imme_out}), .s(BranchResult), .cin(1'b0), .cout(), .last4());

    wire[31:0] alu_out_orMD;

    assign alu_out_orMD =  multDivReady_out ? PW_mulDivRes_out : alu_out;

    // Latch instruction
    wire [31:0] xm_insn_out, xm_pc_out, xm_data_readRegA, xm_data_readRegB, xm_alu_out;
    wire[4:0] xm_rs_out, xm_rt_out, xm_rd_out, xm_shamt_out;
    wire[16:0] xm_imme_out;
    wire[26:0] xm_target_out;

    latch XM(.clk(~clock), .reset(reset), .enable(latchEnable), .pc_in(dx_pc_out), .pc_out(xm_pc_out), .insn_in(dx_insn_out), 
    .insn_out(xm_insn_out), .rs_din(dx_bypass_data_readRegA), .rs_dout(xm_data_readRegA), .rt_din(dx_bypass_data_readRegB), .rt_dout(xm_data_readRegB), 
    .rs_in(dx_rs_out), .rs_out(xm_rs_out), .rt_in(dx_rt_out), .rt_out(xm_rt_out), .rd_in(dx_rd_out), .rd_out(xm_rd_out), .imme_in(dx_imme_out), 
    .imme_out(xm_imme_out), .alu_in(alu_out_orMD), .alu_out(xm_alu_out), .exception_in(over), .exception_out(xm_over), 
    .target_in(dx_target_out), .target_out(xm_target_out));

    // ================MULT AND DIV STAGE================= //
    //make sure to stall and then later worry about wawawawawawawawawawawawawawaw w other alu insn
    //module multdiv(data_operandA, data_operandB, ctrl_MULT, ctrl_DIV, clock, 
    //data_result, data_exception, data_resultRDY);

    //when a mult or div, we need to stall decode and fetch stages, then when the is ready signal is on we know to stop stall

    wire isMult, isDiv, isMultDiv, startMult, startDiv;
    
    wire muldivBusy, muldivBusy_next, validInsn;

    assign validInsn = (dx_insn_out != 32'b0);

    assign isMult = (alu_op == 5'b00110) & validInsn;
    assign isDiv = (alu_op == 5'b00111) & validInsn;
    assign isMultDiv = (isMult | isDiv);

    wire md_bypass_w_rs, md_bypass_m_rs, md_bypass_p_rs;
    wire md_bypassInsn_w_rs, md_bypassInsn_m_rs, md_bypassInsn_p_rs;

    assign md_bypassInsn_w_rs = (RTypeW | mw_Opcode == 5'b00101 | mw_Opcode == 5'b01000);

    assign md_bypassInsn_m_rs = (RTypeM | OpcodeM == 5'b00101 | OpcodeM == 5'b01000) & (xm_insn_out != 32'b0);

    //assign md_bypassInsn_p_rs = (RTypeP | pw_Opcode == 5'b00101 | pw_Opcode == 5'b01000);

    assign md_bypass_w_rs = (dx_rs_out == ctrl_writeReg) & md_bypassInsn_w_rs;
    assign md_bypass_m_rs = (dx_rs_out == xm_rd_out) & md_bypassInsn_m_rs;
   // assign md_bypass_p_rs = (dx_rs_out == ctrl_writeReg) & md_bypassInsn_p_rs & multDivReady_out;

    wire md_bypass_w_rt, md_bypass_m_rt, md_bypass_p_rt;
    wire md_bypassInsn_w_rt, md_bypassInsn_m_rt, md_bypassInsn_p_rt;

    assign md_bypassInsn_w_rt = (RTypeW | mw_Opcode == 5'b00101 | mw_Opcode == 5'b01000);

    assign md_bypassInsn_m_rt = (RTypeM | OpcodeM == 5'b00101 | OpcodeM == 5'b01000) & (xm_insn_out != 32'b0);

    //assign md_bypassInsn_p_rt = (RTypeP | pw_Opcode == 5'b00101);

    assign md_bypass_w_rt = (dx_rt_out == ctrl_writeReg) & md_bypassInsn_w_rt;
    assign md_bypass_m_rt = (dx_rt_out == xm_rd_out) & md_bypassInsn_m_rt;
    //assign md_bypass_p_rt = (dx_rs_out == ctrl_writeReg) & md_bypassInsn_p_rt & multDivReady_out;

    wire[31:0] intoMD_rt_computed, intoMD_rs_computed;

    assign intoMD_rs_computed = (md_bypass_m_rs ? xm_alu_out : (md_bypass_w_rs ? data_writeReg : dx_data_readRegA));

    assign intoMD_rt_computed = (md_bypass_m_rt ? xm_alu_out : (md_bypass_w_rt ? data_writeReg : dx_data_readRegB));

    wire[31:0] intoMD_rs_latched, intoMD_rt_latched;
    wire latch_md_operands;

    assign latch_md_operands = startMult | startDiv;

    register #(.WIDTH(32)) md_rs_reg(.clk(clock), .resetn(reset), .write_en(latch_md_operands), .d(intoMD_rs_computed), 
                                  .out(intoMD_rs_latched));

    register #(.WIDTH(32)) md_rt_reg(.clk(clock), .resetn(reset), .write_en(latch_md_operands), .d(intoMD_rt_computed), 
                                  .out(intoMD_rt_latched));

    wire[31:0] intoMD_rs, intoMD_rt;
    assign intoMD_rs = muldivBusy ? intoMD_rs_latched : intoMD_rs_computed;
    assign intoMD_rt = muldivBusy ? intoMD_rt_latched : intoMD_rt_computed;

    //assign intoMD_rs = md_bypass_p_rs ? PW_mulDivRes_out : (md_bypass_m_rs ? xm_alu_out : (md_bypass_w_rs ? data_writeReg : dx_data_readRegA));
    //assign intoMD_rs = (md_bypass_m_rs ? xm_alu_out : (md_bypass_w_rs ? data_writeReg : into_alu_A_bp));
    //assign intoMD_rt = md_bypass_p_rt ? PW_mulDivRes_out : (md_bypass_m_rt ? xm_alu_out : (md_bypass_w_rt ? data_writeReg : dx_data_readRegB));
    //assign intoMD_rt = (md_bypass_m_rt ? xm_alu_out : (md_bypass_w_rt ? data_writeReg : into_alu_B_bp));
    //if the next cycle we stop muldiving
    assign muldivBusy_next = (muldivBusy & ~multDivReady) | (startMult | startDiv);

    register #(.WIDTH(1)) mulDivBusy(.clk(clock), .resetn(reset), .write_en(1'b1), .d(muldivBusy_next), .out(muldivBusy));

    assign startMult = isMult & ~muldivBusy;
    assign startDiv  = isDiv  & ~muldivBusy;

    //stall if we are muldiving
    assign latchEnable = ~muldivBusy;

    wire multDivReady;
    wire[31:0] multDivRes, PW_mulDivRes_out, multdiv_pc_out, multdiv_insn_out;
    wire[4:0] multDiv_rd_out;
    wire multDiv_exception, multDivReady_out, pw_multDiv_exception;

    multdiv muldiv(.data_operandA(intoMD_rs), .data_operandB(intoMD_rt), .ctrl_MULT(startMult), .ctrl_DIV(startDiv), 
                    .clock(clock), .data_result(multDivRes), .data_exception(multDiv_exception), .data_resultRDY(multDivReady));

        //something is seriously wrong with this latch, i am not sure what the enable should be
     latch PW(.clk(clock), .reset(reset), .enable(1'b1), .pc_in(dx_pc_out), .pc_out(multdiv_pc_out), .insn_in(dx_insn_out), 
     .insn_out(multdiv_insn_out), .rd_in(dx_rd_out), .rd_out(multDiv_rd_out), .muldivRes_in(multDivRes), 
     .muldivRes_out(PW_mulDivRes_out), .mulDivReady_in(multDivReady),
     .mulDivReady_out(multDivReady_out), .exception_in(multDiv_exception), .exception_out(pw_multDiv_exception));

    // ================MEMORY STAGE=============== //

        // Dmem
    //address_dmem,                   // O: The address of the data to get or put from/to dmem
    //data,                           // O: The data to write to dmem
    //wren,                           // O: Write enable for dmem
    //q_dmem,                         // I: The data from dmem

    wire RTypeM;
    wire[4:0] OpcodeM, alu_op_m;

    assign alu_op_m = xm_insn_out[6:2];

    assign OpcodeM = xm_insn_out[31:27];

    assign RTypeM = (xm_insn_out[31:27] == 5'b00000);

    assign address_dmem = xm_alu_out;

    //i gyat to bypass this
    //i will come back to this i cant
    //exception byypassing
    wire xm_is_add_over, xm_is_sub_over, xm_is_addi_over;
    wire[31:0] xm_over_code;

    assign xm_is_add_over  = xm_over & (xm_insn_out[31:27] == 5'b00000) & (xm_insn_out[6:2] == 5'b00000);
    assign xm_is_sub_over  = xm_over & (xm_insn_out[31:27] == 5'b00000) & (xm_insn_out[6:2] == 5'b00001);
    assign xm_is_addi_over = xm_over & (xm_insn_out[31:27] == 5'b00101);

    assign xm_over_code =
        xm_is_add_over  ? 32'd1 :
        xm_is_addi_over ? 32'd2 :
        xm_is_sub_over  ? 32'd3 :
                      32'd0;

    wire[31:0] xm_over_alu_out;
    wire[4:0] xm_over_rd_out;
    assign xm_over_alu_out = xm_over ? xm_over_code : xm_alu_out;

    assign xm_over_rd_out = xm_over ? 5'd30 : xm_rd_out;



    assign data = xm_data_readRegB;
    assign wren = (xm_insn_out[31:27] == 5'b00111);

    wire m_isSetx; 
    assign m_isSetx = (xm_insn_out[31:27] == 5'b10101);

    //latch instruction
    wire [31:0] mw_insn_out, mw_pc_out, mw_data_readRegA, mw_data_readRegB, mw_alu_out, mw_q_dmem;
    wire[4:0] mw_rs_out, mw_rt_out, mw_rd_out, mw_shamt_out;
    wire[16:0] mw_imme_out;
    wire[26:0] mw_target_out;
    wire mw_exception;

    latch MW(.clk(~clock), .reset(reset), .enable(1'b1), .pc_in(xm_pc_out), .pc_out(mw_pc_out), .insn_in(xm_insn_out), 
    .insn_out(mw_insn_out), .rs_din(xm_data_readRegA), .rs_dout(mw_data_readRegA), .rt_din(xm_data_readRegB), .rt_dout(mw_data_readRegB), 
    .rs_in(xm_rs_out), .rs_out(mw_rs_out), .rt_in(xm_rt_out), .rt_out(mw_rt_out), .rd_in(xm_rd_out), .rd_out(mw_rd_out), .imme_in(xm_imme_out), 
    .imme_out(mw_imme_out), .alu_in(xm_alu_out), .alu_out(mw_alu_out), .data_in(q_dmem), .data_out(mw_q_dmem), .exception_in(xm_over),
    .exception_out(mw_exception), .target_in(xm_target_out), .target_out(mw_target_out));

    // ================WRITEBACK STAGE=============== //

    //basically if i have a mult done the pw latch is valid but mw latch is not 
    //but otherwise the mw latch is valid but the pw latch is not so its freaky

    wire[4:0] mw_Opcode, mw_alu_op, pw_alu_op, pw_Opcode;

    assign mw_Opcode = mw_insn_out[31:27];

    assign pw_Opcode = multdiv_insn_out[31:27];
    
    wire w_isMultDiv, RTypeW, RTypeP;

    assign RTypeW = (mw_insn_out[31:27] == 5'b00000);

    assign RTypeP = (multdiv_insn_out[31:27] == 5'b00000);

    assign mw_alu_op = mw_insn_out[6:2];

    assign pw_alu_op = multdiv_insn_out[6:2];

    assign w_isMultDiv = (mw_alu_op == 5'b00110 | mw_alu_op == 5'b00111);

    wire w_isLW, w_isJal, w_isSetx;
    assign w_isLW = (mw_Opcode == 5'b01000);

    assign w_isJal = (mw_Opcode == 5'b00011);

    assign w_isSetx = (mw_Opcode == 5'b10101);

    //exception stuff
    //if we have a mult or alu exception we need to change rd with different stuff
    wire multException, divException, any_exception_orSetx;
    wire addException, addiException, subException;

    //this basically means we need to make changes to reg30
    assign any_exception_orSetx = (multDivReady_out & pw_multDiv_exception) | mw_exception | w_isSetx;

    //ok lol which exception r we then hardcode the code into reg30
    assign multException = (multDivReady_out & pw_multDiv_exception) & (pw_alu_op == 5'b00110);

    assign divException = (multDivReady_out & pw_multDiv_exception) & (pw_alu_op == 5'b00111);

    assign addException = mw_exception & (mw_alu_op == 5'b00000);

    assign subException = mw_exception & (mw_alu_op == 5'b00001);

    assign addiException = mw_exception & (mw_Opcode == 5'b00101);

    // set destination register and data to write
    assign ctrl_writeReg = any_exception_orSetx ? 5'd30 : (multDivReady_out ? multDiv_rd_out : (w_isJal ? 5'd31 : mw_rd_out));
    assign data_writeReg = w_isSetx ? {5'b0 , mw_insn_out[26:0]} : 
                            (addiException ? 32'd2 : 
                            (subException ? 32'd3 : 
                            (addException ? 32'd1 : 
                            (divException ? 32'd5 : 
                            (multException ? 32'd4 : 
                            (multDivReady_out ? PW_mulDivRes_out : 
                            (w_isJal ? mw_pc_out : (w_isLW ? mw_q_dmem : mw_alu_out))))))));
                            //this is horrendous i probably have to fix later
                        // if mult div is ready        or we are doing alu insn and its not multdiv
    assign ctrl_writeEnable = multDivReady_out | ((((mw_Opcode == 5'b00000) & ~(w_isMultDiv)) | 
    (mw_Opcode == 5'b10101) | (mw_Opcode == 5'b00011) | (mw_Opcode == 5'b00101) | (mw_Opcode == 5'b01000)) & (mw_insn_out != 32'b0));  //protecting myself against those nasty stinky no ops
	
	/* END CODE */

endmodule
