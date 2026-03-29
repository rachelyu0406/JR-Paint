`timescale 1 ns / 100 ps

// Build this top with Rachel's processor sources from rachel_processor/proc.
// Do not include Jill's processor tree in the same source set, because both
// implementations use the same Verilog module names.

module FinalProjectVGAProcessor(
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
    input BTNL,
    input BTNR,
    input BTND
);

    localparam VIDEO_WIDTH  = 640;
    localparam VIDEO_HEIGHT = 480;

    localparam CELL_SIZE   = 8;
    localparam GRID_WIDTH  = 80;
    localparam GRID_HEIGHT = 60;
    localparam GRID_COUNT  = GRID_WIDTH * GRID_HEIGHT;
    localparam GRID_ADDR_W = $clog2(GRID_COUNT);

    localparam [31:0] MMIO_BTNU_ADDR = 32'd4096;
    localparam [31:0] MMIO_BTND_ADDR = 32'd4097;
    localparam [31:0] MMIO_BTNL_ADDR = 32'd4098;
    localparam [31:0] MMIO_BTNR_ADDR = 32'd4099;
    localparam [31:0] MMIO_FRAME_ADDR = 32'd4100;
    localparam [31:0] MMIO_CURSOR_X_ADDR = 32'd4101;
    localparam [31:0] MMIO_CURSOR_Y_ADDR = 32'd4102;
    localparam [31:0] MMIO_DRAW_BASE = 32'd8192;
    localparam [31:0] MMIO_DRAW_LAST = MMIO_DRAW_BASE + GRID_COUNT - 1;

    localparam [11:0] WHITE = 12'hFFF;
    localparam [11:0] BLACK = 12'h000;

    localparam CURSOR_SPRITE_SIZE = 50;
    localparam CURSOR_SPRITE_PIXELS = CURSOR_SPRITE_SIZE * CURSOR_SPRITE_SIZE;
    localparam CURSOR_SPRITE_ADDR_W = $clog2(CURSOR_SPRITE_PIXELS);
    localparam CURSOR_CENTER_OFFSET = CELL_SIZE;
    localparam CURSOR_FILE = "cursor.mem";
    localparam COLORS_FILE = "colors.mem";
    localparam [7:0] CURSOR_COLOR_INDEX = 8'd94; // colors.mem[94] = e88

    localparam INSTR_FILE = "finalproject_vga_cpu.mem";

    wire clk25;
    wire locked;
    wire system_reset;
    assign system_reset = reset | ~locked;

    clk_wiz_0 pll (
        .clk_out1(clk25),
        .reset(reset),
        .locked(locked),
        .clk_in1(clk)
    );

    wire active;
    wire screenEnd;
    wire [9:0] x;
    wire [8:0] y;

    VGATimingGenerator #(
        .HEIGHT(VIDEO_HEIGHT),
        .WIDTH(VIDEO_WIDTH)
    ) Display (
        .clk25(clk25),
        .reset(system_reset),
        .screenEnd(screenEnd),
        .active(active),
        .hSync(hSync),
        .vSync(vSync),
        .x(x),
        .y(y)
    );

    reg btnu_meta, btnu_sync;
    reg btnd_meta, btnd_sync;
    reg btnl_meta, btnl_sync;
    reg btnr_meta, btnr_sync;
    reg frame_toggle;

    reg canvas [0:GRID_COUNT-1];
    reg canvas_pixel;
    reg clearing;
    reg [GRID_ADDR_W-1:0] clear_addr;
    reg [6:0] cursor_grid_x;
    reg [5:0] cursor_grid_y;
    reg cursor_sprite [0:CURSOR_SPRITE_PIXELS-1];
    reg cursor_sprite_pixel;
    reg [11:0] color_palette [0:255];
    integer cursor_i;
    integer palette_i;

    wire [6:0] cell_x;
    wire [5:0] cell_y;
    wire [GRID_ADDR_W-1:0] read_addr;

    assign cell_x = x[9:3];
    assign cell_y = y[8:3];
    assign read_addr = cell_y * GRID_WIDTH + cell_x;

    wire cpu_reset;
    assign cpu_reset = system_reset | clearing;

    wire cpu_rwe;
    wire cpu_wren;
    wire [4:0] cpu_wr_reg;
    wire [4:0] cpu_rd_reg_a;
    wire [4:0] cpu_rd_reg_b;
    wire [31:0] cpu_imem_addr;
    wire [31:0] cpu_imem_q;
    wire [31:0] cpu_dmem_addr;
    wire [31:0] cpu_dmem_data;
    wire [31:0] cpu_dmem_q;
    wire [31:0] cpu_reg_write_data;
    wire [31:0] cpu_reg_a_data;
    wire [31:0] cpu_reg_b_data;

    wire cpu_draw_sel;
    wire cpu_readonly_mmio_sel;
    wire cpu_cursor_x_sel;
    wire cpu_cursor_y_sel;
    wire cpu_cursor_mmio_sel;
    wire cpu_ram_wen;
    wire [GRID_ADDR_W-1:0] cpu_draw_addr;
    wire [31:0] ram_q;

    assign cpu_draw_sel = (cpu_dmem_addr >= MMIO_DRAW_BASE) && (cpu_dmem_addr <= MMIO_DRAW_LAST);
    assign cpu_draw_addr = cpu_dmem_addr - MMIO_DRAW_BASE;

    assign cpu_cursor_x_sel = (cpu_dmem_addr == MMIO_CURSOR_X_ADDR);
    assign cpu_cursor_y_sel = (cpu_dmem_addr == MMIO_CURSOR_Y_ADDR);
    assign cpu_cursor_mmio_sel = cpu_cursor_x_sel || cpu_cursor_y_sel;

    assign cpu_readonly_mmio_sel =
        (cpu_dmem_addr == MMIO_BTNU_ADDR)  ||
        (cpu_dmem_addr == MMIO_BTND_ADDR)  ||
        (cpu_dmem_addr == MMIO_BTNL_ADDR)  ||
        (cpu_dmem_addr == MMIO_BTNR_ADDR)  ||
        (cpu_dmem_addr == MMIO_FRAME_ADDR);

    assign cpu_ram_wen = cpu_wren && ~cpu_draw_sel && ~cpu_readonly_mmio_sel && ~cpu_cursor_mmio_sel;

    assign cpu_dmem_q =
        (cpu_dmem_addr == MMIO_BTNU_ADDR)  ? {31'd0, btnu_sync} :
        (cpu_dmem_addr == MMIO_BTND_ADDR)  ? {31'd0, btnd_sync} :
        (cpu_dmem_addr == MMIO_BTNL_ADDR)  ? {31'd0, btnl_sync} :
        (cpu_dmem_addr == MMIO_BTNR_ADDR)  ? {31'd0, btnr_sync} :
        (cpu_dmem_addr == MMIO_FRAME_ADDR) ? {31'd0, frame_toggle} :
        cpu_cursor_x_sel                    ? {25'd0, cursor_grid_x} :
        cpu_cursor_y_sel                    ? {26'd0, cursor_grid_y} :
        cpu_draw_sel                       ? {31'd0, canvas[cpu_draw_addr]} :
                                             ram_q;

    processor CPU (
        .clock(clk25),
        .reset(cpu_reset),
        .address_imem(cpu_imem_addr),
        .q_imem(cpu_imem_q),
        .address_dmem(cpu_dmem_addr),
        .data(cpu_dmem_data),
        .wren(cpu_wren),
        .q_dmem(cpu_dmem_q),
        .ctrl_writeEnable(cpu_rwe),
        .ctrl_writeReg(cpu_wr_reg),
        .ctrl_readRegA(cpu_rd_reg_a),
        .ctrl_readRegB(cpu_rd_reg_b),
        .data_writeReg(cpu_reg_write_data),
        .data_readRegA(cpu_reg_a_data),
        .data_readRegB(cpu_reg_b_data)
    );

    FinalProjectVGAROM #(
        .MEMFILE(INSTR_FILE)
    ) InstMem (
        .clk(clk25),
        .addr(cpu_imem_addr[11:0]),
        .dataOut(cpu_imem_q)
    );

    regfile RegisterFile (
        .clock(clk25),
        .ctrl_writeEnable(cpu_rwe),
        .ctrl_reset(cpu_reset),
        .ctrl_writeReg(cpu_wr_reg),
        .ctrl_readRegA(cpu_rd_reg_a),
        .ctrl_readRegB(cpu_rd_reg_b),
        .data_writeReg(cpu_reg_write_data),
        .data_readRegA(cpu_reg_a_data),
        .data_readRegB(cpu_reg_b_data)
    );

    FinalProjectVGARAM ProcMem (
        .clk(clk25),
        .wEn(cpu_ram_wen),
        .addr(cpu_dmem_addr[11:0]),
        .dataIn(cpu_dmem_data),
        .dataOut(ram_q)
    );

    initial begin
        for (cursor_i = 0; cursor_i < CURSOR_SPRITE_PIXELS; cursor_i = cursor_i + 1)
            cursor_sprite[cursor_i] = 1'b0;
        $readmemh(CURSOR_FILE, cursor_sprite);
    end

    initial begin
        for (palette_i = 0; palette_i < 256; palette_i = palette_i + 1)
            color_palette[palette_i] = 12'h000;
        $readmemh(COLORS_FILE, color_palette);
    end

    wire [11:0] cursor_color;
    assign cursor_color = color_palette[CURSOR_COLOR_INDEX];

    wire signed [11:0] screen_x_signed;
    wire signed [11:0] screen_y_signed;
    wire signed [11:0] cursor_origin_x;
    wire signed [11:0] cursor_origin_y;
    wire in_cursor_sprite;
    wire [5:0] cursor_local_x;
    wire [5:0] cursor_local_y;
    wire [CURSOR_SPRITE_ADDR_W-1:0] cursor_sprite_addr;

    assign screen_x_signed = $signed({2'b00, x});
    assign screen_y_signed = $signed({3'b000, y});
    assign cursor_origin_x = $signed({2'b00, cursor_grid_x, 3'b000}) + CURSOR_CENTER_OFFSET - (CURSOR_SPRITE_SIZE / 2);
    assign cursor_origin_y = $signed({3'b000, cursor_grid_y, 3'b000}) + CURSOR_CENTER_OFFSET - (CURSOR_SPRITE_SIZE / 2);

    assign in_cursor_sprite =
        active &&
        (screen_x_signed >= cursor_origin_x) &&
        (screen_x_signed < cursor_origin_x + CURSOR_SPRITE_SIZE) &&
        (screen_y_signed >= cursor_origin_y) &&
        (screen_y_signed < cursor_origin_y + CURSOR_SPRITE_SIZE);

    assign cursor_local_x = screen_x_signed - cursor_origin_x;
    assign cursor_local_y = screen_y_signed - cursor_origin_y;
    assign cursor_sprite_addr = cursor_local_y * CURSOR_SPRITE_SIZE + cursor_local_x;

    always @(*) begin
        if (in_cursor_sprite)
            cursor_sprite_pixel = cursor_sprite[cursor_sprite_addr];
        else
            cursor_sprite_pixel = 1'b0;
    end

    always @(posedge clk25) begin
        canvas_pixel <= canvas[read_addr];

        if (clearing)
            canvas[clear_addr] <= 1'b0;
        else if (cpu_wren && cpu_draw_sel)
            canvas[cpu_draw_addr] <= cpu_dmem_data[0];
    end

    always @(posedge clk25 or posedge system_reset) begin
        if (system_reset) begin
            btnu_meta   <= 1'b0;
            btnu_sync   <= 1'b0;
            btnd_meta   <= 1'b0;
            btnd_sync   <= 1'b0;
            btnl_meta   <= 1'b0;
            btnl_sync   <= 1'b0;
            btnr_meta   <= 1'b0;
            btnr_sync   <= 1'b0;
            frame_toggle <= 1'b0;
            clearing    <= 1'b1;
            clear_addr  <= {GRID_ADDR_W{1'b0}};
            cursor_grid_x <= GRID_WIDTH / 2;
            cursor_grid_y <= GRID_HEIGHT / 2;
        end else begin
            btnu_meta <= BTNU;
            btnu_sync <= btnu_meta;
            btnd_meta <= BTND;
            btnd_sync <= btnd_meta;
            btnl_meta <= BTNL;
            btnl_sync <= btnl_meta;
            btnr_meta <= BTNR;
            btnr_sync <= btnr_meta;

            if (cpu_wren && cpu_cursor_x_sel)
                cursor_grid_x <= cpu_dmem_data[6:0];

            if (cpu_wren && cpu_cursor_y_sel)
                cursor_grid_y <= cpu_dmem_data[5:0];

            if (screenEnd)
                frame_toggle <= ~frame_toggle;

            if (clearing) begin
                if (clear_addr == GRID_COUNT - 1) begin
                    clearing   <= 1'b0;
                    clear_addr <= {GRID_ADDR_W{1'b0}};
                end else begin
                    clear_addr <= clear_addr + 1'b1;
                end
            end
        end
    end

    wire [11:0] colorOut;
    assign colorOut = active ? (cursor_sprite_pixel ? 12'hF00 : ((clearing || ~canvas_pixel) ? 12'h0F0 : 12'h00F)) : 12'h000;
    assign {VGA_R, VGA_G, VGA_B} = colorOut;

    assign ps2_clk  = 1'bz;
    assign ps2_data = 1'bz;

endmodule

module FinalProjectVGAROM #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS_WIDTH = 12,
    parameter DEPTH = 4096,
    parameter MEMFILE = ""
) (
    input wire clk,
    input wire [ADDRESS_WIDTH-1:0] addr,
    output reg [DATA_WIDTH-1:0] dataOut = 0
);
    reg [DATA_WIDTH-1:0] MemoryArray [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            MemoryArray[i] = {DATA_WIDTH{1'b0}};

        if (MEMFILE != "")
            $readmemb(MEMFILE, MemoryArray);
    end

    always @(posedge clk) begin
        dataOut <= MemoryArray[addr];
    end
endmodule

module FinalProjectVGARAM #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS_WIDTH = 12,
    parameter DEPTH = 4096
) (
    input wire clk,
    input wire wEn,
    input wire [ADDRESS_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] dataIn,
    output reg [DATA_WIDTH-1:0] dataOut = 0
);
    reg [DATA_WIDTH-1:0] MemoryArray [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            MemoryArray[i] = {DATA_WIDTH{1'b0}};
    end

    always @(posedge clk) begin
        if (wEn)
            MemoryArray[addr] <= dataIn;
        else
            dataOut <= MemoryArray[addr];
    end
endmodule
