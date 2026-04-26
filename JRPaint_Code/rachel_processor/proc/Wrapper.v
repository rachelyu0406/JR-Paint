`timescale 1ns / 1ps

// Simple top-level wrapper for running the processor with the provided
// instruction ROM, data RAM, and register file.

module Wrapper (clock, reset);
    input clock, reset;

    wire rwe, mwe;
    wire [4:0] rd, rs1, rs2;
    wire [31:0] instAddr, instData;
    wire [31:0] rData, regA, regB;
    wire [31:0] memAddr, memDataIn, memDataOut;

    // Set this to the assembled program name without the .mem suffix.
    localparam INSTR_FILE = "";

    processor CPU(
        .clock(clock),
        .reset(reset),
        .address_imem(instAddr),
        .q_imem(instData),
        .ctrl_writeEnable(rwe),
        .ctrl_writeReg(rd),
        .ctrl_readRegA(rs1),
        .ctrl_readRegB(rs2),
        .data_writeReg(rData),
        .data_readRegA(regA),
        .data_readRegB(regB),
        .wren(mwe),
        .address_dmem(memAddr),
        .data(memDataIn),
        .q_dmem(memDataOut)
    );

    ROM #(.MEMFILE({INSTR_FILE, ".mem"})) InstMem(
        .clk(clock),
        .addr(instAddr[11:0]),
        .dataOut(instData)
    );

    regfile RegisterFile(
        .clock(clock),
        .ctrl_writeEnable(rwe),
        .ctrl_reset(reset),
        .ctrl_writeReg(rd),
        .ctrl_readRegA(rs1),
        .ctrl_readRegB(rs2),
        .data_writeReg(rData),
        .data_readRegA(regA),
        .data_readRegB(regB)
    );

    RAM ProcMem(
        .clk(clock),
        .wEn(mwe),
        .addr(memAddr[11:0]),
        .dataIn(memDataIn),
        .dataOut(memDataOut)
    );

endmodule
