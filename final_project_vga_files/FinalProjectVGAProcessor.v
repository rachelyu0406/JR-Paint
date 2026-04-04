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

    localparam [31:0] MMIO_BTNU_ADDR     = 32'd4096;
    localparam [31:0] MMIO_BTND_ADDR     = 32'd4097;
    localparam [31:0] MMIO_BTNL_ADDR     = 32'd4098;
    localparam [31:0] MMIO_BTNR_ADDR     = 32'd4099;
    localparam [31:0] MMIO_FRAME_ADDR    = 32'd4100;
    localparam [31:0] MMIO_CURSOR_X_ADDR = 32'd4101;
    localparam [31:0] MMIO_CURSOR_Y_ADDR = 32'd4102;
    localparam [31:0] MMIO_DRAW_BASE     = 32'd8192;
    localparam [31:0] MMIO_DRAW_LAST     = MMIO_DRAW_BASE + GRID_COUNT - 1;

    localparam [11:0] WHITE = 12'hFFF;
    localparam [11:0] BLACK = 12'h000;

    localparam CURSOR_SIZE   = 50;
    localparam CURSOR_PIXELS = CURSOR_SIZE * CURSOR_SIZE;
    localparam CURSOR_ADDR_W = $clog2(CURSOR_PIXELS) + 1;
    localparam signed [11:0] CURSOR_OFFSET = CELL_SIZE - (CURSOR_SIZE / 2);
    localparam CURSOR_FILE = "cursor.mem";
    localparam INSTR_FILE  = "finalproject_vga_cpu.mem";
    localparam [11:0] CURSOR_COLOR = 12'hE88;

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

    wire [6:0] cell_x;
    wire [5:0] cell_y;
    wire [GRID_ADDR_W-1:0] canvas_read_addr;
    assign cell_x = x[9:3];
    assign cell_y = y[8:3];
    assign canvas_read_addr = cell_y * GRID_WIDTH + cell_x;

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

    processor CPU (
        .clock(clk25),
        .reset(system_reset),
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

    ROM #(
        .MEMFILE(INSTR_FILE)
    ) InstMem (
        .clk(clk25),
        .addr(cpu_imem_addr[11:0]),
        .dataOut(cpu_imem_q)
    );

    regfile RegisterFile (
        .clock(clk25),
        .ctrl_writeEnable(cpu_rwe),
        .ctrl_reset(system_reset),
        .ctrl_writeReg(cpu_wr_reg),
        .ctrl_readRegA(cpu_rd_reg_a),
        .ctrl_readRegB(cpu_rd_reg_b),
        .data_writeReg(cpu_reg_write_data),
        .data_readRegA(cpu_reg_a_data),
        .data_readRegB(cpu_reg_b_data)
    );

    wire draw_write;
    wire cursor_x_write;
    wire cursor_y_write;
    wire proc_mem_wen;
    wire [GRID_ADDR_W-1:0] draw_addr;
    wire [31:0] proc_mem_q;

    assign draw_write = cpu_wren && (cpu_dmem_addr >= MMIO_DRAW_BASE) && (cpu_dmem_addr <= MMIO_DRAW_LAST);
    assign cursor_x_write = cpu_wren && (cpu_dmem_addr == MMIO_CURSOR_X_ADDR);
    assign cursor_y_write = cpu_wren && (cpu_dmem_addr == MMIO_CURSOR_Y_ADDR);
    assign proc_mem_wen = cpu_wren && ~draw_write && ~cursor_x_write && ~cursor_y_write;
    assign draw_addr = cpu_dmem_addr - MMIO_DRAW_BASE;

    RAM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(12),
        .DEPTH(4096)
    ) ProcMem (
        .clk(clk25),
        .wEn(proc_mem_wen),
        .addr(cpu_dmem_addr[11:0]),
        .dataIn(cpu_dmem_data),
        .dataOut(proc_mem_q)
    );

    wire [GRID_ADDR_W-1:0] canvas_addr;
    wire canvas_bit;
    assign canvas_addr = draw_write ? draw_addr : canvas_read_addr;

    RAM #(
        .DEPTH(GRID_COUNT),
        .DATA_WIDTH(1),
        .ADDRESS_WIDTH(GRID_ADDR_W)
    ) CanvasMem (
        .clk(clk25),
        .wEn(draw_write),
        .addr(canvas_addr),
        .dataIn(cpu_dmem_data[0]),
        .dataOut(canvas_bit)
    );

    reg frame_toggle;
    reg [6:0] cursor_x;
    reg [5:0] cursor_y;
    reg active_d;
    reg in_cursor_d;
    reg canvas_read_d;
    reg mmio_read_d;
    reg [31:0] mmio_q;

    assign cpu_dmem_q = mmio_read_d ? mmio_q : proc_mem_q;

    wire signed [11:0] cursor_origin_x;
    wire signed [11:0] cursor_origin_y;
    wire signed [11:0] screen_x;
    wire signed [11:0] screen_y;
    wire in_cursor;
    wire [5:0] cursor_local_x;
    wire [5:0] cursor_local_y;
    wire [CURSOR_ADDR_W-1:0] cursor_addr;
    wire cursor_bit;

    assign screen_x = $signed({2'b00, x});
    assign screen_y = $signed({3'b000, y});
    assign cursor_origin_x = $signed({2'b00, cursor_x, 3'b000}) + CURSOR_OFFSET;
    assign cursor_origin_y = $signed({3'b000, cursor_y, 3'b000}) + CURSOR_OFFSET;

    assign in_cursor =
        active &&
        (screen_x >= cursor_origin_x) &&
        (screen_x < cursor_origin_x + CURSOR_SIZE) &&
        (screen_y >= cursor_origin_y) &&
        (screen_y < cursor_origin_y + CURSOR_SIZE);

    assign cursor_local_x = screen_x - cursor_origin_x;
    assign cursor_local_y = screen_y - cursor_origin_y;
    assign cursor_addr = cursor_local_y * CURSOR_SIZE + cursor_local_x;

    ROM #(
        .DATA_WIDTH(1),
        .ADDRESS_WIDTH(CURSOR_ADDR_W),
        .DEPTH(CURSOR_PIXELS),
        .MEMFILE(CURSOR_FILE)
    ) CursorSprite (
        .clk(clk25),
        .addr(cursor_addr),
        .dataOut(cursor_bit)
    );

    always @(posedge clk25 or posedge system_reset) begin
        if (system_reset) begin
            frame_toggle <= 1'b0;
            cursor_x <= GRID_WIDTH / 2;
            cursor_y <= GRID_HEIGHT / 2;
            active_d <= 1'b0;
            in_cursor_d <= 1'b0;
            canvas_read_d <= 1'b0;
            mmio_read_d <= 1'b0;
            mmio_q <= 32'd0;
        end else begin
            active_d <= active;
            in_cursor_d <= in_cursor;
            canvas_read_d <= ~draw_write;

            if (screenEnd)
                frame_toggle <= ~frame_toggle;

            if (cursor_x_write)
                cursor_x <= cpu_dmem_data[6:0];

            if (cursor_y_write)
                cursor_y <= cpu_dmem_data[5:0];

            mmio_read_d <= 1'b1;
            case (cpu_dmem_addr)
                MMIO_BTNU_ADDR:     mmio_q <= {31'd0, BTNU};
                MMIO_BTND_ADDR:     mmio_q <= {31'd0, BTND};
                MMIO_BTNL_ADDR:     mmio_q <= {31'd0, BTNL};
                MMIO_BTNR_ADDR:     mmio_q <= {31'd0, BTNR};
                MMIO_FRAME_ADDR:    mmio_q <= {31'd0, frame_toggle};
                MMIO_CURSOR_X_ADDR: mmio_q <= {25'd0, cursor_x};
                MMIO_CURSOR_Y_ADDR: mmio_q <= {26'd0, cursor_y};
                default: begin
                    mmio_read_d <= 1'b0;
                    mmio_q <= 32'd0;
                end
            endcase
        end
    end

    wire [11:0] draw_color;
    wire [11:0] colorOut;

    assign draw_color = (canvas_read_d && canvas_bit) ? BLACK : WHITE;
    assign colorOut = active_d ? ((in_cursor_d && cursor_bit) ? CURSOR_COLOR : draw_color) : BLACK;

    assign {VGA_R, VGA_G, VGA_B} = colorOut;
    assign ps2_clk = 1'bz;
    assign ps2_data = 1'bz;

endmodule
