`timescale 1 ns / 100 ps

// Build this top with Rachel's processor sources from rachel_processor/proc.
// Do not include Jill's processor tree in the same source set, because both
// implementations use the same Verilog module names.

module FinalProjectVGAProcessor(
    input clk,
    output hSync,
    output vSync,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output LED17_B,
    output LED17_G,
    output LED17_R,
    output DISP_SEG_A,
    output DISP_SEG_B,
    output DISP_SEG_C,
    output DISP_SEG_D,
    output DISP_SEG_E,
    output DISP_SEG_F,
    output DISP_SEG_G,
    output DISP_DP,
    output [7:0] DISP_EN,
    inout ps2_clk,
    inout ps2_data,
    input [14:0] SW,
    input BTNU,
    input BTNL,
    input BTNR,
    input BTND,
    input BTNC
);

    localparam VIDEO_W = 640;
    localparam VIDEO_H = 480;

    localparam CELL_SIZE  = 8;
    localparam GRID_W     = 80;
    localparam GRID_H     = 60;
    localparam GRID_COUNT = GRID_W * GRID_H;
    localparam GRID_AW    = $clog2(GRID_COUNT);

    localparam [31:0] MMIO_BTNU   = 32'd4096;
    localparam [31:0] MMIO_BTND   = 32'd4097;
    localparam [31:0] MMIO_BTNL   = 32'd4098;
    localparam [31:0] MMIO_BTNR   = 32'd4099;
    localparam [31:0] MMIO_FRAME  = 32'd4100;
    localparam [31:0] MMIO_CX     = 32'd4101;
    localparam [31:0] MMIO_CY     = 32'd4102;
    localparam [31:0] MMIO_BTNC   = 32'd4103;
    localparam [31:0] MMIO_SW     = 32'd4104;
    localparam [31:0] MMIO_LED    = 32'd4105;
    localparam [31:0] MMIO_PEN    = 32'd4106;
    localparam [31:0] DRAW_BASE   = 32'd8192;
    localparam [31:0] DRAW_LAST   = DRAW_BASE + GRID_COUNT - 1;

    localparam CURSOR_SIZE   = 50;
    localparam CURSOR_PIXELS = CURSOR_SIZE * CURSOR_SIZE;
    localparam CURSOR_AW     = $clog2(CURSOR_PIXELS) + 1;
    localparam signed [11:0] CURSOR_OFF = (CELL_SIZE / 2) - (CURSOR_SIZE / 2);
    localparam [7:0] CURSOR_COLOR = 8'd94;

    reg [11:0] palette[0:255];
    initial $readmemh("colors.mem", palette);

    wire clk25;
    wire locked;
    wire reset;
    assign reset = ~locked;

    clk_wiz_0 pll (
        .clk_out1(clk25),
        .reset(1'b0),
        .locked(locked),
        .clk_in1(clk)
    );

    wire active;
    wire screenEnd;
    wire [9:0] x;
    wire [8:0] y;

    VGATimingGenerator #(
        .HEIGHT(VIDEO_H),
        .WIDTH(VIDEO_W)
    ) Display (
        .clk25(clk25),
        .reset(reset),
        .screenEnd(screenEnd),
        .active(active),
        .hSync(hSync),
        .vSync(vSync),
        .x(x),
        .y(y)
    );

    wire [GRID_AW-1:0] displayAddr;
    assign displayAddr = y[8:3] * GRID_W + x[9:3];

    wire regWriteEn;
    wire memWriteEn;
    wire [4:0] regWriteAddr;
    wire [4:0] regReadAddrA;
    wire [4:0] regReadAddrB;
    wire [31:0] imemAddr;
    wire [31:0] imemQ;
    wire [31:0] dmemAddr;
    wire [31:0] dmemData;
    wire [31:0] dmemQ;
    wire [31:0] regWriteData;
    wire [31:0] regReadDataA;
    wire [31:0] regReadDataB;

    processor CPU (
        .clock(clk25),
        .reset(reset),
        .address_imem(imemAddr),
        .q_imem(imemQ),
        .address_dmem(dmemAddr),
        .data(dmemData),
        .wren(memWriteEn),
        .q_dmem(dmemQ),
        .ctrl_writeEnable(regWriteEn),
        .ctrl_writeReg(regWriteAddr),
        .ctrl_readRegA(regReadAddrA),
        .ctrl_readRegB(regReadAddrB),
        .data_writeReg(regWriteData),
        .data_readRegA(regReadDataA),
        .data_readRegB(regReadDataB)
    );

    ROM #(
        .MEMFILE("finalproject_vga_cpu.mem")
    ) InstMem (
        .clk(clk25),
        .addr(imemAddr[11:0]),
        .dataOut(imemQ)
    );

    regfile RegisterFile (
        .clock(clk25),
        .ctrl_writeEnable(regWriteEn),
        .ctrl_reset(reset),
        .ctrl_writeReg(regWriteAddr),
        .ctrl_readRegA(regReadAddrA),
        .ctrl_readRegB(regReadAddrB),
        .data_writeReg(regWriteData),
        .data_readRegA(regReadDataA),
        .data_readRegB(regReadDataB)
    );

    wire drawWrite;
    wire cxWrite;
    wire cyWrite;
    wire ledWrite;
    wire penWrite;
    wire ramWrite;
    wire [GRID_AW-1:0] drawAddr;
    wire [31:0] ramQ;

    assign drawWrite = memWriteEn && (dmemAddr >= DRAW_BASE) && (dmemAddr <= DRAW_LAST);
    assign cxWrite = memWriteEn && (dmemAddr == MMIO_CX);
    assign cyWrite = memWriteEn && (dmemAddr == MMIO_CY);
    assign ledWrite = memWriteEn && (dmemAddr == MMIO_LED);
    assign penWrite = memWriteEn && (dmemAddr == MMIO_PEN);
    assign ramWrite = memWriteEn && ~drawWrite && ~cxWrite && ~cyWrite && ~ledWrite && ~penWrite;
    assign drawAddr = dmemAddr - DRAW_BASE;

    RAM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(12),
        .DEPTH(4096)
    ) ProcMem (
        .clk(clk25),
        .wEn(ramWrite),
        .addr(dmemAddr[11:0]),
        .dataIn(dmemData),
        .dataOut(ramQ)
    );

    wire [GRID_AW-1:0] canvasAddr;
    wire [3:0] canvasColor;
    assign canvasAddr = drawWrite ? drawAddr : displayAddr;

    RAM #(
        .DEPTH(GRID_COUNT),
        .DATA_WIDTH(4),
        .ADDRESS_WIDTH(GRID_AW)
    ) CanvasMemory (
        .clk(clk25),
        .wEn(drawWrite),
        .addr(canvasAddr),
        .dataIn(dmemData[3:0]),
        .dataOut(canvasColor)
    );

    reg frameToggle;
    reg [6:0] cursorX;
    reg [5:0] cursorY;
    reg [3:0] ledColor;
    reg [2:0] penSize;
    reg [15:0] dispCount;
    reg active_q;
    reg inCursor_q;
    reg canvasRead_q;
    reg mmioRead_q;
    reg [31:0] mmioData;

    assign dmemQ = mmioRead_q ? mmioData : ramQ;

    wire signed [11:0] sx;
    wire signed [11:0] sy;
    wire signed [11:0] cursorLeft;
    wire signed [11:0] cursorTop;
    wire inCursor;
    wire [5:0] cursorLocalX;
    wire [5:0] cursorLocalY;
    wire [CURSOR_AW-1:0] cursorAddr;
    wire cursorPixel;

    assign sx = $signed({2'b00, x});
    assign sy = $signed({3'b000, y});
    assign cursorLeft = $signed({2'b00, cursorX, 3'b000}) + CURSOR_OFF;
    assign cursorTop = $signed({3'b000, cursorY, 3'b000}) + CURSOR_OFF;

    assign inCursor =
        active &&
        (sx >= cursorLeft) &&
        (sx < cursorLeft + CURSOR_SIZE) &&
        (sy >= cursorTop) &&
        (sy < cursorTop + CURSOR_SIZE);

    assign cursorLocalX = sx - cursorLeft;
    assign cursorLocalY = sy - cursorTop;
    assign cursorAddr = cursorLocalY * CURSOR_SIZE + cursorLocalX;

    ROM #(
        .DATA_WIDTH(1),
        .ADDRESS_WIDTH(CURSOR_AW),
        .DEPTH(CURSOR_PIXELS),
        .MEMFILE("cursor.mem")
    ) CursorSprite (
        .clk(clk25),
        .addr(cursorAddr),
        .dataOut(cursorPixel)
    );

    always @(posedge clk25 or posedge reset) begin
        if (reset) begin
            frameToggle <= 1'b0;
            cursorX <= GRID_W / 2;
            cursorY <= GRID_H / 2;
            ledColor <= 4'd0;
            penSize <= 3'd1;
            dispCount <= 16'd0;
            active_q <= 1'b0;
            inCursor_q <= 1'b0;
            canvasRead_q <= 1'b0;
            mmioRead_q <= 1'b0;
            mmioData <= 32'd0;
        end else begin
            active_q <= active;
            inCursor_q <= inCursor;
            canvasRead_q <= ~drawWrite;
            dispCount <= dispCount + 16'd1;

            if (screenEnd)
                frameToggle <= ~frameToggle;

            if (cxWrite)
                cursorX <= dmemData[6:0];

            if (cyWrite)
                cursorY <= dmemData[5:0];

            if (ledWrite)
                ledColor <= dmemData[3:0];

            if (penWrite)
                penSize <= dmemData[2:0];

            mmioRead_q <= 1'b1;
            case (dmemAddr)
                MMIO_BTNU:  mmioData <= {31'd0, BTNU};
                MMIO_BTND:  mmioData <= {31'd0, BTND};
                MMIO_BTNL:  mmioData <= {31'd0, BTNL};
                MMIO_BTNR:  mmioData <= {31'd0, BTNR};
                MMIO_FRAME: mmioData <= {31'd0, frameToggle};
                MMIO_CX:    mmioData <= {25'd0, cursorX};
                MMIO_CY:    mmioData <= {26'd0, cursorY};
                MMIO_BTNC:  mmioData <= {31'd0, BTNC};
                MMIO_SW:    mmioData <= {17'd0, SW};
                MMIO_LED:   mmioData <= {28'd0, ledColor};
                MMIO_PEN:   mmioData <= {29'd0, penSize};
                default: begin
                    mmioRead_q <= 1'b0;
                    mmioData <= 32'd0;
                end
            endcase
        end
    end

    wire [11:0] colorData;
    assign colorData = active_q
        ? ((inCursor_q && cursorPixel) ? palette[CURSOR_COLOR]
                                       : (canvasRead_q ? palette[canvasColor] : palette[0]))
        : palette[10];

    assign {VGA_R, VGA_G, VGA_B} = colorData;
    assign LED17_R = (ledColor != 4'd0) && |palette[ledColor][11:8];
    assign LED17_G = (ledColor != 4'd0) && |palette[ledColor][7:4];
    assign LED17_B = (ledColor != 4'd0) && |palette[ledColor][3:0];

    assign {DISP_SEG_A, DISP_SEG_B, DISP_SEG_C, DISP_SEG_D, DISP_SEG_E, DISP_SEG_F, DISP_SEG_G} =
        dispCount[15]
            ? ((penSize == 3'd5) ? 7'b1001111 : 7'b0000001)
            : ((penSize == 3'd1) ? 7'b0010010 :
               (penSize == 3'd2) ? 7'b1001100 :
               (penSize == 3'd3) ? 7'b0100000 :
               (penSize == 3'd4) ? 7'b0000000 :
                                   7'b0000001);
    assign DISP_DP = ~dispCount[15];
    assign DISP_EN = dispCount[15] ? 8'b11111101 : 8'b11111110;

    assign ps2_clk = 1'bz;
    assign ps2_data = 1'bz;

endmodule
