`timescale 1 ns / 100 ps
module VGAController(
    input clk,          // 100 MHz System Clock
    input reset,        // Reset Signal
    output hSync,       // H Sync Signal
    output vSync,       // Vertical Sync Signal
    output [3:0] VGA_R, // Red Signal Bits
    output [3:0] VGA_G, // Green Signal Bits
    output [3:0] VGA_B, // Blue Signal Bits
    inout ps2_clk,
    inout ps2_data,
    input BTNU,
    input BTNL,
    input BTNR,
    input BTND
);

    // Keep empty for project-relative .mem file paths.
    localparam FILES_PATH = "";

    localparam VIDEO_WIDTH = 640;
    localparam VIDEO_HEIGHT = 480;
    localparam PIXEL_COUNT = VIDEO_WIDTH * VIDEO_HEIGHT;
    localparam PIXEL_ADDRESS_WIDTH = $clog2(PIXEL_COUNT) + 1;
    localparam BITS_PER_COLOR = 12;
    localparam PALETTE_COLOR_COUNT = 256;
    localparam PALETTE_ADDRESS_WIDTH = $clog2(PALETTE_COLOR_COUNT) + 1;

    localparam SPRITE_SIZE = 50;
    localparam SPRITE_PIXELS = SPRITE_SIZE * SPRITE_SIZE; // 2500
    localparam SPRITE_COUNT = 94; // Printable ASCII: 0x21..0x7E
    localparam SPRITE_ROM_DEPTH = SPRITE_COUNT * SPRITE_PIXELS; // 235000
    localparam SPRITE_ADDR_WIDTH = $clog2(SPRITE_ROM_DEPTH) + 1;
    localparam SPRITE_PIXEL_ADDR_WIDTH = $clog2(SPRITE_PIXELS) + 1;

    localparam STEP = 4;
    localparam [11:0] SPRITE_COLOR = 12'hFFF;
    localparam [7:0] DEFAULT_ASCII = 8'h41; // 'A'

    // Clock divider 100 MHz -> 25 MHz
    wire clk25;
    wire locked;

    clk_wiz_0 pll (
        .clk_out1(clk25),
        .reset(reset),
        .locked(locked),
        .clk_in1(clk)
    );

    // VGA timing for 640x480
    wire active, screenEnd;
    wire [9:0] x;
    wire [8:0] y;

    VGATimingGenerator #(
        .HEIGHT(VIDEO_HEIGHT),
        .WIDTH(VIDEO_WIDTH)
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

    // Background image + palette
    wire [PIXEL_ADDRESS_WIDTH-1:0] imgAddress;
    wire [PALETTE_ADDRESS_WIDTH-1:0] colorAddr;
    wire [BITS_PER_COLOR-1:0] colorData;
    assign imgAddress = x + VIDEO_WIDTH * y;

    RAM #(
        .DEPTH(PIXEL_COUNT),
        .DATA_WIDTH(PALETTE_ADDRESS_WIDTH),
        .ADDRESS_WIDTH(PIXEL_ADDRESS_WIDTH),
        .MEMFILE({FILES_PATH, "image.mem"})
    ) ImageData (
        .clk(clk25),
        .wEn(1'b0),
        .addr(imgAddress),
        .dataIn({PALETTE_ADDRESS_WIDTH{1'b0}}),
        .dataOut(colorAddr)
    );

    RAM #(
        .DEPTH(PALETTE_COLOR_COUNT),
        .DATA_WIDTH(BITS_PER_COLOR),
        .ADDRESS_WIDTH(PALETTE_ADDRESS_WIDTH),
        .MEMFILE({FILES_PATH, "colors.mem"})
    ) ColorPalette (
        .clk(clk25),
        .wEn(1'b0),
        .addr(colorAddr),
        .dataIn({BITS_PER_COLOR{1'b0}}),
        .dataOut(colorData)
    );

    // Sprite position
    reg [9:0] x_pos;
    reg [8:0] y_pos;

    always @(posedge clk25 or posedge reset) begin
        if (reset) begin
            x_pos <= 10'd100;
            y_pos <= 9'd100;
        end else if (screenEnd) begin
            if (BTNU && (y_pos >= STEP))
                y_pos <= y_pos - STEP;
            else if (BTND && (y_pos + SPRITE_SIZE + STEP <= VIDEO_HEIGHT))
                y_pos <= y_pos + STEP;

            if (BTNL && (x_pos >= STEP))
                x_pos <= x_pos - STEP;
            else if (BTNR && (x_pos + SPRITE_SIZE + STEP <= VIDEO_WIDTH))
                x_pos <= x_pos + STEP;
        end
    end

    // Fixed character selection
    wire printable_char;
    wire [6:0] sprite_index;

    assign printable_char = (DEFAULT_ASCII >= 8'h21) && (DEFAULT_ASCII <= 8'h7E);
    assign sprite_index = DEFAULT_ASCII - 8'h21;

    // Check if current screen pixel is inside sprite box
    wire inSprite;
    assign inSprite =
        (x >= x_pos) && (x < x_pos + SPRITE_SIZE) &&
        (y >= y_pos) && (y < y_pos + SPRITE_SIZE);

    wire [5:0] sprite_local_x;
    wire [5:0] sprite_local_y;
    assign sprite_local_x = x - x_pos;
    assign sprite_local_y = y - y_pos;

    wire [SPRITE_PIXEL_ADDR_WIDTH-1:0] sprite_pixel_addr;
    wire [SPRITE_ADDR_WIDTH-1:0] sprite_addr;
    assign sprite_pixel_addr = sprite_local_y * SPRITE_SIZE + sprite_local_x;
    assign sprite_addr = sprite_index * SPRITE_PIXELS + sprite_pixel_addr;

    wire sprite_bit;
    RAM #(
        .DEPTH(SPRITE_ROM_DEPTH),
        .DATA_WIDTH(1),
        .ADDRESS_WIDTH(SPRITE_ADDR_WIDTH),
        .MEMFILE({FILES_PATH, "sprites.mem"})
    ) SpriteROM (
        .clk(clk25),
        .wEn(1'b0),
        .addr(sprite_addr),
        .dataIn(1'b0),
        .dataOut(sprite_bit)
    );

    // Delay background/control by 1 cycle to match synchronous sprite ROM
    wire [BITS_PER_COLOR-1:0] bgColor;
    wire [BITS_PER_COLOR-1:0] colorOut;
    reg [BITS_PER_COLOR-1:0] bgColor_d;
    reg inSprite_d;
    reg printable_char_d;

    assign bgColor = active ? colorData : 12'h000;

    always @(posedge clk25 or posedge reset) begin
        if (reset) begin
            bgColor_d <= 12'h000;
            inSprite_d <= 1'b0;
            printable_char_d <= 1'b0;
        end else begin
            bgColor_d <= bgColor;
            inSprite_d <= inSprite;
            printable_char_d <= printable_char;
        end
    end

    assign colorOut = (inSprite_d && printable_char_d && sprite_bit) ? SPRITE_COLOR : bgColor_d;

    assign {VGA_R, VGA_G, VGA_B} = colorOut;

endmodule