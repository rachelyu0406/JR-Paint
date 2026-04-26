`timescale 1 ns / 100 ps

module VGAController(
    input clk,          // 100 MHz board clock
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

    localparam FILES_PATH = "C:/Users/ckw24/Documents/lab6_kit/";
    localparam VIDEO_WIDTH = 640;
    localparam VIDEO_HEIGHT = 480;
    localparam PIXEL_COUNT = VIDEO_WIDTH * VIDEO_HEIGHT;
    localparam PIXEL_ADDRESS_WIDTH = $clog2(PIXEL_COUNT) + 1;
    localparam BITS_PER_COLOR = 12;
    localparam PALETTE_COLOR_COUNT = 256;
    localparam PALETTE_ADDRESS_WIDTH = $clog2(PALETTE_COLOR_COUNT) + 1;

    // Divide the 100 MHz input clock down to 25 MHz for VGA timing.
    reg [1:0] pixCounter = 0;
    wire clk25 = pixCounter[1];

    always @(posedge clk) begin
        pixCounter <= pixCounter + 1;
    end

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
        .screenEnd(screenEnd),
        .active(active),
        .hSync(hSync),
        .vSync(vSync),
        .x(x),
        .y(y)
    );

    wire [PIXEL_ADDRESS_WIDTH-1:0] imgAddress;
    wire [PALETTE_ADDRESS_WIDTH-1:0] colorAddr;
    assign imgAddress = x + (VIDEO_WIDTH * y);

    RAM #(
        .DEPTH(PIXEL_COUNT),
        .DATA_WIDTH(PALETTE_ADDRESS_WIDTH),
        .ADDRESS_WIDTH(PIXEL_ADDRESS_WIDTH),
        .MEMFILE({FILES_PATH, "image.mem"})
    ) ImageData (
        .clk(clk),
        .addr(imgAddress),
        .dataOut(colorAddr),
        .wEn(1'b0)
    );

    wire [BITS_PER_COLOR-1:0] colorData;

    RAM #(
        .DEPTH(PALETTE_COLOR_COUNT),
        .DATA_WIDTH(BITS_PER_COLOR),
        .ADDRESS_WIDTH(PALETTE_ADDRESS_WIDTH),
        .MEMFILE({FILES_PATH, "colors.mem"})
    ) ColorPalette (
        .clk(clk),
        .addr(colorAddr),
        .dataOut(colorData),
        .wEn(1'b0)
    );

    reg [9:0] sprite_x_ref;
    reg [8:0] sprite_y_ref;

    wire in_bounds;
    assign in_bounds =
        ((x >= sprite_x_ref) & (x <= sprite_x_ref + 50)) &
        ((y >= sprite_y_ref) & (y <= sprite_y_ref + 50));

    initial begin
        sprite_x_ref = 10'd0;
        sprite_y_ref = 9'd0;
    end

    always @(posedge screenEnd) begin
        if (BTNR & (sprite_x_ref < VIDEO_WIDTH - 50))
            sprite_x_ref = sprite_x_ref + 1;
        if (BTNL & (sprite_x_ref > 0))
            sprite_x_ref = sprite_x_ref - 1;
        if (BTND & (sprite_y_ref < VIDEO_HEIGHT - 50))
            sprite_y_ref = sprite_y_ref + 1;
        if (BTNU & (sprite_y_ref > 0))
            sprite_y_ref = sprite_y_ref - 1;
    end

    wire [7:0] new_scancode;
    wire data_available;
    reg [7:0] old_scancode;

    Ps2Interface USB_to_Ps2 (
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .rst(reset),
        .clk(clk),
        .tx_data(8'd0),
        .write_data(1'b0),
        .rx_data(new_scancode),
        .read_data(data_available)
    );

    initial begin
        old_scancode = 8'h1c;
    end

    always @(data_available) begin
        if (new_scancode != 8'hf0) begin
            old_scancode = new_scancode;
        end
    end

    assign LED[7:0] = old_scancode;
    assign LED[8] = data_available;
    assign LED[9] = 1'b1;

    wire [7:0] ascii_value;
    RAM #(
        .DEPTH(256),
        .DATA_WIDTH(8),
        .ADDRESS_WIDTH(8),
        .MEMFILE({FILES_PATH, "ascii.mem"})
    ) scandcode_to_ascii (
        .clk(clk),
        .addr(old_scancode),
        .dataOut(ascii_value),
        .wEn(1'b0)
    );

    wire sprite_bit;
    RAM #(
        .DEPTH(50 * 50 * 94),
        .DATA_WIDTH(1),
        .ADDRESS_WIDTH($clog2(50 * 50 * 94) + 1),
        .MEMFILE({FILES_PATH, "sprites.mem"})
    ) ascii_to_sprite (
        .clk(clk),
        .addr((x - sprite_x_ref) + 2500 * (ascii_value - 33) + 50 * (y - sprite_y_ref)),
        .dataOut(sprite_bit),
        .wEn(1'b0)
    );

    wire [BITS_PER_COLOR-1:0] sprite_color;
    wire [BITS_PER_COLOR-1:0] colorSelect;
    wire [BITS_PER_COLOR-1:0] colorOut;

    assign sprite_color = sprite_bit ? 12'h000 : 12'hfff;
    assign colorSelect = in_bounds ? sprite_color : colorData;
    assign colorOut = active ? colorSelect : 12'd0;

    assign {VGA_R, VGA_G, VGA_B} = colorOut;
endmodule
