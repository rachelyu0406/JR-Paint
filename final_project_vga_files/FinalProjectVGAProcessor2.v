`timescale 1ns / 1ps

module FinalProjectVGAProcessor2(
    input clk,
    input reset,
    output hSync,
    output vSync,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    inout ps2_clk,
    inout ps2_data,
    input BTNU,
    input BTND,
    input BTNL,
    input BTNR,
    output [9:0] LED
);

    localparam FILES_PATH = "final_project_vga_files/";

    localparam VIDEO_WIDTH  = 640;
    localparam VIDEO_HEIGHT = 480;

    localparam BORDER    = 50;
    localparam CELL_SIZE = 10;

    localparam CURSOR_W      = 50;
    localparam CURSOR_H      = 50;
    localparam CURSOR_CELLS  = CURSOR_W / CELL_SIZE;

    localparam DRAW_WIDTH  = VIDEO_WIDTH  - (2 * BORDER);
    localparam DRAW_HEIGHT = VIDEO_HEIGHT - (2 * BORDER);

    localparam GRID_W    = DRAW_WIDTH  / CELL_SIZE;
    localparam GRID_H    = DRAW_HEIGHT / CELL_SIZE;
    localparam GRID_SIZE = GRID_W * GRID_H;

    localparam DEFAULT_CURSOR_X = (GRID_W - CURSOR_CELLS) / 2;
    localparam DEFAULT_CURSOR_Y = (GRID_H - CURSOR_CELLS) / 2;

    localparam MMIO_BTNS     = 32'd0;
    localparam MMIO_CURSOR_X = 32'd1;
    localparam MMIO_CURSOR_Y = 32'd2;
    localparam MMIO_TICK     = 32'd3;

    localparam IMEM_DEPTH = 4096;
    localparam IMEM_AW    = 12;

    assign ps2_clk = 1'bz;
    assign ps2_data = 1'bz;
    assign LED = 10'b0;

    /* -------------------- 25 MHz VGA clock -------------------- */

    reg [1:0] pixCounter = 2'b00;
    wire clk25 = pixCounter[1];

    always @(posedge clk) begin
        if (reset) begin
            pixCounter <= 2'b00;
        end else begin
            pixCounter <= pixCounter + 2'b01;
        end
    end

    /* -------------------- VGA timing -------------------- */

    wire active;
    wire screenEnd;
    wire [9:0] x;
    wire [8:0] y;

    VGATimingGenerator #(
        .HEIGHT(VIDEO_HEIGHT),
        .WIDTH(VIDEO_WIDTH)
    ) Display (
        .clk25(clk25),
        .reset(reset),
        .active(active),
        .screenEnd(screenEnd),
        .hSync(hSync),
        .vSync(vSync),
        .x(x),
        .y(y)
    );

    /* -------------------- Processor wrapper -------------------- */

    wire [31:0] address_imem;
    wire [31:0] q_imem;

    wire [31:0] address_dmem;
    wire [31:0] data_dmem;
    wire        wren;
    wire [31:0] q_dmem;

    wire        ctrl_writeEnable;
    wire [4:0]  ctrl_writeReg;
    wire [4:0]  ctrl_readRegA;
    wire [4:0]  ctrl_readRegB;
    wire [31:0] data_writeReg;
    wire [31:0] data_readRegA;
    wire [31:0] data_readRegB;

    processor CPU (
        .clock(clk),
        .reset(reset),

        .address_imem(address_imem),
        .q_imem(q_imem),

        .address_dmem(address_dmem),
        .data(data_dmem),
        .wren(wren),
        .q_dmem(q_dmem),

        .ctrl_writeEnable(ctrl_writeEnable),
        .ctrl_writeReg(ctrl_writeReg),
        .ctrl_readRegA(ctrl_readRegA),
        .ctrl_readRegB(ctrl_readRegB),
        .data_writeReg(data_writeReg),
        .data_readRegA(data_readRegA),
        .data_readRegB(data_readRegB)
    );

    RAM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(IMEM_AW),
        .DEPTH(IMEM_DEPTH),
        .MEMFILE({FILES_PATH, "finalproject_vga_cpu.mem"})
    ) InstructionMemory (
        .clk(clk),
        .wEn(1'b0),
        .addr(address_imem[IMEM_AW-1:0]),
        .dataIn(32'b0),
        .dataOut(q_imem)
    );

    fp_regfile RegFile (
        .clk(clk),
        .reset(reset),
        .write_enable(ctrl_writeEnable),
        .write_reg(ctrl_writeReg),
        .read_reg_a(ctrl_readRegA),
        .read_reg_b(ctrl_readRegB),
        .write_data(data_writeReg),
        .read_data_a(data_readRegA),
        .read_data_b(data_readRegB)
    );

    /* -------------------- MMIO state -------------------- */

    reg [5:0] cursor_x_reg = DEFAULT_CURSOR_X[5:0];
    reg [5:0] cursor_y_reg = DEFAULT_CURSOR_Y[5:0];

    reg [GRID_SIZE-1:0] trail_mem = {GRID_SIZE{1'b0}};

    reg screenEnd_meta   = 1'b0;
    reg screenEnd_sync   = 1'b0;
    reg screenEnd_sync_d = 1'b0;
    reg frame_tick_reg   = 1'b0;

    reg [31:0] q_dmem_reg = 32'b0;
    assign q_dmem = q_dmem_reg;

    wire [11:0] current_draw_index;
    assign current_draw_index = ((cursor_y_reg + 6'd2) * GRID_W) + (cursor_x_reg + 6'd2);

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            cursor_x_reg <= DEFAULT_CURSOR_X[5:0];
            cursor_y_reg <= DEFAULT_CURSOR_Y[5:0];
            trail_mem <= {GRID_SIZE{1'b0}};
            screenEnd_meta <= 1'b0;
            screenEnd_sync <= 1'b0;
            screenEnd_sync_d <= 1'b0;
            frame_tick_reg <= 1'b0;
            q_dmem_reg <= 32'b0;
        end else begin
            screenEnd_meta <= screenEnd;
            screenEnd_sync <= screenEnd_meta;
            screenEnd_sync_d <= screenEnd_sync;

            if (screenEnd_sync & ~screenEnd_sync_d) begin
                frame_tick_reg <= ~frame_tick_reg;
            end

            case (address_dmem)
                MMIO_BTNS:     q_dmem_reg <= {28'b0, BTNR, BTNL, BTND, BTNU};
                MMIO_CURSOR_X: q_dmem_reg <= {26'b0, cursor_x_reg};
                MMIO_CURSOR_Y: q_dmem_reg <= {26'b0, cursor_y_reg};
                MMIO_TICK:     q_dmem_reg <= {31'b0, frame_tick_reg};
                default:       q_dmem_reg <= 32'b0;
            endcase

            if (wren) begin
                if (address_dmem == MMIO_CURSOR_X) begin
                    cursor_x_reg <= data_dmem[5:0];
                end
                if (address_dmem == MMIO_CURSOR_Y) begin
                    cursor_y_reg <= data_dmem[5:0];
                end
            end

            trail_mem[current_draw_index] <= 1'b1;
        end
    end

    /* -------------------- Cursor sprite -------------------- */

    wire [9:0] cursor_px;
    wire [8:0] cursor_py;

    assign cursor_px = BORDER + (cursor_x_reg * CELL_SIZE);
    assign cursor_py = BORDER + (cursor_y_reg * CELL_SIZE);

    wire cursor_region;
    assign cursor_region =
        (x >= cursor_px) && (x < (cursor_px + CURSOR_W)) &&
        (y >= cursor_py) && (y < (cursor_py + CURSOR_H));

    wire [5:0] cursor_local_x;
    wire [5:0] cursor_local_y;
    assign cursor_local_x = x - cursor_px;
    assign cursor_local_y = y - cursor_py;

    wire [11:0] cursor_addr;
    assign cursor_addr = (cursor_local_y * CURSOR_W) + cursor_local_x;

    wire cursor_sprite_bit;

    RAM #(
        .DATA_WIDTH(1),
        .ADDRESS_WIDTH(12),
        .DEPTH(CURSOR_W * CURSOR_H),
        .MEMFILE({FILES_PATH, "cursor.mem"})
    ) CursorSprite (
        .clk(clk25),
        .wEn(1'b0),
        .addr(cursor_addr),
        .dataIn(1'b0),
        .dataOut(cursor_sprite_bit)
    );

    /* -------------------- Pixel generation -------------------- */

    wire inside_draw_area;
    assign inside_draw_area =
        (x >= BORDER) && (x < (VIDEO_WIDTH - BORDER)) &&
        (y >= BORDER) && (y < (VIDEO_HEIGHT - BORDER));

    wire [9:0] draw_x;
    wire [8:0] draw_y;
    assign draw_x = x - BORDER;
    assign draw_y = y - BORDER;

    wire [5:0] cell_x;
    wire [5:0] cell_y;
    assign cell_x = draw_x / CELL_SIZE;
    assign cell_y = draw_y / CELL_SIZE;

    wire [11:0] trail_index;
    assign trail_index = (cell_y * GRID_W) + cell_x;

    wire trail_on;
    assign trail_on = inside_draw_area ? trail_mem[trail_index] : 1'b0;

    wire border_on;
    assign border_on = active & ~inside_draw_area;

    wire cursor_on;
    assign cursor_on = cursor_region & cursor_sprite_bit;

    wire pixel_black;
    assign pixel_black = border_on | trail_on | cursor_on;

    wire [11:0] colorOut;
    assign colorOut = active ? (pixel_black ? 12'h000 : 12'hfff) : 12'h000;

    assign {VGA_R, VGA_G, VGA_B} = colorOut;

endmodule


module fp_regfile(
    input clk,
    input reset,
    input write_enable,
    input [4:0] write_reg,
    input [4:0] read_reg_a,
    input [4:0] read_reg_b,
    input [31:0] write_data,
    output [31:0] read_data_a,
    output [31:0] read_data_b
);

    reg [31:0] regs[0:31];
    integer k;

    always @(posedge clk) begin
        if (reset) begin
            for (k = 0; k < 32; k = k + 1) begin
                regs[k] <= 32'b0;
            end
        end else begin
            if (write_enable && (write_reg != 5'd0)) begin
                regs[write_reg] <= write_data;
            end
            regs[0] <= 32'b0;
        end
    end

    assign read_data_a = (read_reg_a == 5'd0) ? 32'b0 : regs[read_reg_a];
    assign read_data_b = (read_reg_b == 5'd0) ? 32'b0 : regs[read_reg_b];

endmodule