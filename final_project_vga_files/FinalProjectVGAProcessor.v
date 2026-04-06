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

    localparam VIDEO_WIDTH  = 640;
    localparam VIDEO_HEIGHT = 480;

    localparam CELL_SIZE       = 8;
    localparam GRID_WIDTH      = 80;
    localparam GRID_HEIGHT     = 60;
    localparam GRID_CELL_COUNT = GRID_WIDTH * GRID_HEIGHT;
    localparam GRID_ADDR_WIDTH = $clog2(GRID_CELL_COUNT);

    localparam [31:0] MMIO_UP_BUTTON_ADDR        = 32'd4096;
    localparam [31:0] MMIO_DOWN_BUTTON_ADDR      = 32'd4097;
    localparam [31:0] MMIO_LEFT_BUTTON_ADDR      = 32'd4098;
    localparam [31:0] MMIO_RIGHT_BUTTON_ADDR     = 32'd4099;
    localparam [31:0] MMIO_FRAME_TOGGLE_ADDR     = 32'd4100;
    localparam [31:0] MMIO_CURSOR_X_ADDR         = 32'd4101;
    localparam [31:0] MMIO_CURSOR_Y_ADDR         = 32'd4102;
    localparam [31:0] MMIO_CENTER_BUTTON_ADDR    = 32'd4103;
    localparam [31:0] MMIO_SWITCHES_ADDR         = 32'd4104;
    localparam [31:0] MMIO_RGB_LED_COLOR_ADDR    = 32'd4105;
    localparam [31:0] MMIO_PEN_SIZE_ADDR         = 32'd4106;
    localparam [31:0] MMIO_CANVAS_BASE_ADDR      = 32'd8192;
    localparam [31:0] MMIO_CANVAS_LAST_ADDR      = MMIO_CANVAS_BASE_ADDR + GRID_CELL_COUNT - 1;

    localparam CURSOR_SPRITE_SIZE       = 50;
    localparam CURSOR_SPRITE_PIXEL_COUNT = CURSOR_SPRITE_SIZE * CURSOR_SPRITE_SIZE;
    localparam CURSOR_SPRITE_ADDR_WIDTH = $clog2(CURSOR_SPRITE_PIXEL_COUNT) + 1;
    localparam signed [11:0] CURSOR_SPRITE_OFFSET = (CELL_SIZE / 2) - (CURSOR_SPRITE_SIZE / 2);
    localparam PALETTE_MEM_FILE         = "colors.mem";
    localparam CURSOR_SPRITE_MEM_FILE   = "cursor.mem";
    localparam INSTRUCTION_MEM_FILE     = "finalproject_vga_cpu.mem";
    localparam [7:0] CURSOR_PALETTE_INDEX = 8'd94;

    reg [11:0] color_palette [0:255];
    initial $readmemh(PALETTE_MEM_FILE, color_palette);

    wire pixel_clk;
    wire pll_locked;
    wire reset;
    assign reset = ~pll_locked;

    clk_wiz_0 pll (
        .clk_out1(pixel_clk),
        .reset(1'b0),
        .locked(pll_locked),
        .clk_in1(clk)
    );

    wire video_active;
    wire frame_end_pulse;
    wire [9:0] pixel_x;
    wire [8:0] pixel_y;

    VGATimingGenerator #(
        .HEIGHT(VIDEO_HEIGHT),
        .WIDTH(VIDEO_WIDTH)
    ) VideoTiming (
        .clk25(pixel_clk),
        .reset(reset),
        .screenEnd(frame_end_pulse),
        .active(video_active),
        .hSync(hSync),
        .vSync(vSync),
        .x(pixel_x),
        .y(pixel_y)
    );

    wire [6:0] grid_x;
    wire [5:0] grid_y;
    wire [GRID_ADDR_WIDTH-1:0] canvas_display_addr;
    assign grid_x = pixel_x[9:3];
    assign grid_y = pixel_y[8:3];
    assign canvas_display_addr = grid_y * GRID_WIDTH + grid_x;

    wire cpu_reg_write_en;
    wire cpu_data_write_en;
    wire [4:0] cpu_reg_write_addr;
    wire [4:0] cpu_reg_read_addr_a;
    wire [4:0] cpu_reg_read_addr_b;
    wire [31:0] cpu_instruction_addr;
    wire [31:0] cpu_instruction_data;
    wire [31:0] cpu_data_addr;
    wire [31:0] cpu_data_write_value;
    wire [31:0] cpu_data_read_value;
    wire [31:0] cpu_reg_write_value;
    wire [31:0] cpu_reg_read_value_a;
    wire [31:0] cpu_reg_read_value_b;

    processor ProcessorCore (
        .clock(pixel_clk),
        .reset(reset),
        .address_imem(cpu_instruction_addr),
        .q_imem(cpu_instruction_data),
        .address_dmem(cpu_data_addr),
        .data(cpu_data_write_value),
        .wren(cpu_data_write_en),
        .q_dmem(cpu_data_read_value),
        .ctrl_writeEnable(cpu_reg_write_en),
        .ctrl_writeReg(cpu_reg_write_addr),
        .ctrl_readRegA(cpu_reg_read_addr_a),
        .ctrl_readRegB(cpu_reg_read_addr_b),
        .data_writeReg(cpu_reg_write_value),
        .data_readRegA(cpu_reg_read_value_a),
        .data_readRegB(cpu_reg_read_value_b)
    );

    ROM #(
        .MEMFILE(INSTRUCTION_MEM_FILE)
    ) InstructionMemory (
        .clk(pixel_clk),
        .addr(cpu_instruction_addr[11:0]),
        .dataOut(cpu_instruction_data)
    );

    regfile ProcessorRegisterFile (
        .clock(pixel_clk),
        .ctrl_writeEnable(cpu_reg_write_en),
        .ctrl_reset(reset),
        .ctrl_writeReg(cpu_reg_write_addr),
        .ctrl_readRegA(cpu_reg_read_addr_a),
        .ctrl_readRegB(cpu_reg_read_addr_b),
        .data_writeReg(cpu_reg_write_value),
        .data_readRegA(cpu_reg_read_value_a),
        .data_readRegB(cpu_reg_read_value_b)
    );

    wire canvas_mmio_write_en;
    wire cursor_x_mmio_write_en;
    wire cursor_y_mmio_write_en;
    wire rgb_led_mmio_write_en;
    wire pen_size_mmio_write_en;
    wire cpu_ram_write_en;
    wire [GRID_ADDR_WIDTH-1:0] canvas_mmio_addr;
    wire [31:0] cpu_ram_read_value;

    assign canvas_mmio_write_en = cpu_data_write_en && (cpu_data_addr >= MMIO_CANVAS_BASE_ADDR) && (cpu_data_addr <= MMIO_CANVAS_LAST_ADDR);
    assign cursor_x_mmio_write_en = cpu_data_write_en && (cpu_data_addr == MMIO_CURSOR_X_ADDR);
    assign cursor_y_mmio_write_en = cpu_data_write_en && (cpu_data_addr == MMIO_CURSOR_Y_ADDR);
    assign rgb_led_mmio_write_en = cpu_data_write_en && (cpu_data_addr == MMIO_RGB_LED_COLOR_ADDR);
    assign pen_size_mmio_write_en = cpu_data_write_en && (cpu_data_addr == MMIO_PEN_SIZE_ADDR);
    assign cpu_ram_write_en = cpu_data_write_en &&
                              ~canvas_mmio_write_en &&
                              ~cursor_x_mmio_write_en &&
                              ~cursor_y_mmio_write_en &&
                              ~rgb_led_mmio_write_en &&
                              ~pen_size_mmio_write_en;
    assign canvas_mmio_addr = cpu_data_addr - MMIO_CANVAS_BASE_ADDR;

    RAM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(12),
        .DEPTH(4096)
    ) ProcessorDataMemory (
        .clk(pixel_clk),
        .wEn(cpu_ram_write_en),
        .addr(cpu_data_addr[11:0]),
        .dataIn(cpu_data_write_value),
        .dataOut(cpu_ram_read_value)
    );

    wire [GRID_ADDR_WIDTH-1:0] canvas_ram_addr;
    wire [3:0] canvas_cell_color;
    assign canvas_ram_addr = canvas_mmio_write_en ? canvas_mmio_addr : canvas_display_addr;

    RAM #(
        .DEPTH(GRID_CELL_COUNT),
        .DATA_WIDTH(4),
        .ADDRESS_WIDTH(GRID_ADDR_WIDTH)
    ) CanvasMemory (
        .clk(pixel_clk),
        .wEn(canvas_mmio_write_en),
        .addr(canvas_ram_addr),
        .dataIn(cpu_data_write_value[3:0]),
        .dataOut(canvas_cell_color)
    );

    reg frame_toggle_bit;
    reg [6:0] cursor_grid_x;
    reg [5:0] cursor_grid_y;
    reg [3:0] rgb_led_color_code;
    reg [2:0] pen_size_code;
    reg video_active_q;
    reg cursor_hit_q;
    reg canvas_display_read_q;
    reg mmio_read_valid_q;
    reg [31:0] mmio_read_data_q;

    assign cpu_data_read_value = mmio_read_valid_q ? mmio_read_data_q : cpu_ram_read_value;

    wire signed [11:0] cursor_sprite_origin_x;
    wire signed [11:0] cursor_sprite_origin_y;
    wire signed [11:0] signed_pixel_x;
    wire signed [11:0] signed_pixel_y;
    wire cursor_hit;
    wire [5:0] cursor_sprite_x;
    wire [5:0] cursor_sprite_y;
    wire [CURSOR_SPRITE_ADDR_WIDTH-1:0] cursor_sprite_addr;
    wire cursor_sprite_pixel;

    assign signed_pixel_x = $signed({2'b00, pixel_x});
    assign signed_pixel_y = $signed({3'b000, pixel_y});
    assign cursor_sprite_origin_x = $signed({2'b00, cursor_grid_x, 3'b000}) + CURSOR_SPRITE_OFFSET;
    assign cursor_sprite_origin_y = $signed({3'b000, cursor_grid_y, 3'b000}) + CURSOR_SPRITE_OFFSET;

    assign cursor_hit =
        video_active &&
        (signed_pixel_x >= cursor_sprite_origin_x) &&
        (signed_pixel_x < cursor_sprite_origin_x + CURSOR_SPRITE_SIZE) &&
        (signed_pixel_y >= cursor_sprite_origin_y) &&
        (signed_pixel_y < cursor_sprite_origin_y + CURSOR_SPRITE_SIZE);

    assign cursor_sprite_x = signed_pixel_x - cursor_sprite_origin_x;
    assign cursor_sprite_y = signed_pixel_y - cursor_sprite_origin_y;
    assign cursor_sprite_addr = cursor_sprite_y * CURSOR_SPRITE_SIZE + cursor_sprite_x;

    ROM #(
        .DATA_WIDTH(1),
        .ADDRESS_WIDTH(CURSOR_SPRITE_ADDR_WIDTH),
        .DEPTH(CURSOR_SPRITE_PIXEL_COUNT),
        .MEMFILE(CURSOR_SPRITE_MEM_FILE)
    ) CursorSpriteMemory (
        .clk(pixel_clk),
        .addr(cursor_sprite_addr),
        .dataOut(cursor_sprite_pixel)
    );

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            frame_toggle_bit <= 1'b0;
            cursor_grid_x <= GRID_WIDTH / 2;
            cursor_grid_y <= GRID_HEIGHT / 2;
            rgb_led_color_code <= 4'd0;
            pen_size_code <= 3'd1;
            video_active_q <= 1'b0;
            cursor_hit_q <= 1'b0;
            canvas_display_read_q <= 1'b0;
            mmio_read_valid_q <= 1'b0;
            mmio_read_data_q <= 32'd0;
        end else begin
            video_active_q <= video_active;
            cursor_hit_q <= cursor_hit;
            canvas_display_read_q <= ~canvas_mmio_write_en;

            if (frame_end_pulse)
                frame_toggle_bit <= ~frame_toggle_bit;

            if (cursor_x_mmio_write_en)
                cursor_grid_x <= cpu_data_write_value[6:0];

            if (cursor_y_mmio_write_en)
                cursor_grid_y <= cpu_data_write_value[5:0];

            if (rgb_led_mmio_write_en)
                rgb_led_color_code <= cpu_data_write_value[3:0];

            if (pen_size_mmio_write_en)
                pen_size_code <= cpu_data_write_value[2:0];

            mmio_read_valid_q <= 1'b1;
            case (cpu_data_addr)
                MMIO_UP_BUTTON_ADDR:      mmio_read_data_q <= {31'd0, BTNU};
                MMIO_DOWN_BUTTON_ADDR:    mmio_read_data_q <= {31'd0, BTND};
                MMIO_LEFT_BUTTON_ADDR:    mmio_read_data_q <= {31'd0, BTNL};
                MMIO_RIGHT_BUTTON_ADDR:   mmio_read_data_q <= {31'd0, BTNR};
                MMIO_FRAME_TOGGLE_ADDR:   mmio_read_data_q <= {31'd0, frame_toggle_bit};
                MMIO_CURSOR_X_ADDR:       mmio_read_data_q <= {25'd0, cursor_grid_x};
                MMIO_CURSOR_Y_ADDR:       mmio_read_data_q <= {26'd0, cursor_grid_y};
                MMIO_CENTER_BUTTON_ADDR:  mmio_read_data_q <= {31'd0, BTNC};
                MMIO_SWITCHES_ADDR:       mmio_read_data_q <= {17'd0, SW};
                MMIO_RGB_LED_COLOR_ADDR:  mmio_read_data_q <= {28'd0, rgb_led_color_code};
                MMIO_PEN_SIZE_ADDR:       mmio_read_data_q <= {29'd0, pen_size_code};
                default: begin
                    mmio_read_valid_q <= 1'b0;
                    mmio_read_data_q <= 32'd0;
                end
            endcase
        end
    end

    wire [11:0] canvas_pixel_color;
    wire [11:0] pixel_color;

    assign canvas_pixel_color = ~canvas_display_read_q ? color_palette[0] : color_palette[canvas_cell_color];
    assign pixel_color = video_active_q
        ? ((cursor_hit_q && cursor_sprite_pixel) ? color_palette[CURSOR_PALETTE_INDEX] : canvas_pixel_color)
        : color_palette[10];

    assign {VGA_R, VGA_G, VGA_B} = pixel_color;
    assign LED17_R = (rgb_led_color_code != 4'd0) && |color_palette[rgb_led_color_code][11:8];
    assign LED17_G = (rgb_led_color_code != 4'd0) && |color_palette[rgb_led_color_code][7:4];
    assign LED17_B = (rgb_led_color_code != 4'd0) && |color_palette[rgb_led_color_code][3:0];
    assign {DISP_SEG_A, DISP_SEG_B, DISP_SEG_C, DISP_SEG_D, DISP_SEG_E, DISP_SEG_F, DISP_SEG_G} =
        (pen_size_code == 3'd1) ? 7'b0010010 :
        (pen_size_code == 3'd2) ? 7'b1001100 :
        (pen_size_code == 3'd3) ? 7'b0100000 :
        (pen_size_code == 3'd4) ? 7'b0000000 :
                                  7'b1001111;
    assign DISP_DP = (pen_size_code == 3'd5);
    assign DISP_EN = 8'b11111101;
    assign ps2_clk = 1'bz;
    assign ps2_data = 1'bz;

endmodule
