// `timescale 1 ns/ 100 ps
// module VGAController(     
// 	input clk, 			// 100 MHz System Clock
// 	input reset, 		// Reset Signal
// 	output hSync, 		// H Sync Signal
// 	output vSync, 		// Vertical Sync Signal
// 	output[3:0] VGA_R,  // Red Signal Bits
// 	output[3:0] VGA_G,  // Green Signal Bits
// 	output[3:0] VGA_B,  // Blue Signal Bits
// 	inout ps2_clk,
// 	inout ps2_data,
// 	input BTNU,
// 	input BTNL,
// 	input BTNR,
// 	input BTND
// 	);
	
// 	// Lab Memory Files Location
// 	localparam FILES_PATH = "C:/Users/jaw185/Documents/lab7-8_kit/";

// 	// Clock divider 100 MHz -> 25 MHz
// 	wire clk25; // 25MHz clock
// 	wire locked; // dummy wire that goes high when the output clock has stabilized at specified frequency

// 	// Using PLL to make a 25 MHz clock
// 	clk_wiz_0 pll(
// 		.clk_out1(clk25), 	// 25 MHz output clock
// 		.reset(reset),
// 		.locked(locked), 
// 		.clk_in1(clk)); 	// 100 MHz system clock input

// 	// VGA Timing Generation for a Standard VGA Screen
// 	localparam 
// 		VIDEO_WIDTH = 640,  // Standard VGA Width
// 		VIDEO_HEIGHT = 480; // Standard VGA Height

// 	wire active, screenEnd;
// 	wire[9:0] x;
// 	wire[8:0] y;
	
// 	VGATimingGenerator #(
// 		.HEIGHT(VIDEO_HEIGHT), // Use the standard VGA Values
// 		.WIDTH(VIDEO_WIDTH))
// 	Display( 
// 		.clk25(clk25),  	   // 25MHz Pixel Clock
// 		.reset(reset),		   // Reset Signal
// 		.screenEnd(screenEnd), // High for one cycle when between two frames
// 		.active(active),	   // High when drawing pixels
// 		.hSync(hSync),  	   // Set Generated H Signal
// 		.vSync(vSync),		   // Set Generated V Signal
// 		.x(x), 				   // X Coordinate (from left)
// 		.y(y)); 			   // Y Coordinate (from top)	   

// 	// Image Data to Map Pixel Location to Color Address
// 	localparam 
// 		PIXEL_COUNT = VIDEO_WIDTH*VIDEO_HEIGHT, 	             // Number of pixels on the screen
// 		PIXEL_ADDRESS_WIDTH = $clog2(PIXEL_COUNT) + 1,           // Use built in log2 command
// 		BITS_PER_COLOR = 12, 	  								 // Nexys A7 uses 12 bits/color
// 		PALETTE_COLOR_COUNT = 256, 								 // Number of Colors available
// 		PALETTE_ADDRESS_WIDTH = $clog2(PALETTE_COLOR_COUNT) + 1; // Use built in log2 Command

// 	wire[PIXEL_ADDRESS_WIDTH-1:0] imgAddress;  	 // Image address for the image data
// 	wire[PALETTE_ADDRESS_WIDTH-1:0] colorAddr; 	 // Color address for the color palette
// 	assign imgAddress = x + 640*y;				 // Address calculated coordinate

// 	RAM #(		
// 		.DEPTH(PIXEL_COUNT), 				     // Set RAM depth to contain every pixel
// 		.DATA_WIDTH(PALETTE_ADDRESS_WIDTH),      // Set data width according to the color palette
// 		.ADDRESS_WIDTH(PIXEL_ADDRESS_WIDTH),     // Set address with according to the pixel count
// 		.MEMFILE({FILES_PATH, "image.mem"})) // Memory initialization
// 	ImageData(
// 		.clk(clk), 						 // Falling edge of the 100 MHz clk
// 		.addr(imgAddress),					 // Image data address
// 		.dataOut(colorAddr),				 // Color palette address
// 		.wEn(1'b0)); 						 // We're always reading

// 	// Color Palette to Map Color Address to 12-Bit Color
// 	wire[BITS_PER_COLOR-1:0] colorData; // 12-bit color data at current pixel

// 	RAM #(
// 		.DEPTH(PALETTE_COLOR_COUNT), 		       // Set depth to contain every color		
// 		.DATA_WIDTH(BITS_PER_COLOR), 		       // Set data width according to the bits per color
// 		.ADDRESS_WIDTH(PALETTE_ADDRESS_WIDTH),     // Set address width according to the color count
// 		.MEMFILE({FILES_PATH, "colors.mem"}))  // Memory initialization
// 	ColorPalette(
// 		.clk(clk), 							   	   // Rising edge of the 100 MHz clk
// 		.addr(colorAddr),					       // Address from the ImageData RAM
// 		.dataOut(colorData),				       // Color at current pixel
// 		.wEn(1'b0)); 						       // We're always reading
	

// // Assign to output color from register if active
// wire[BITS_PER_COLOR-1:0] colorOut; // Output color 

// reg[9:0] x_reg;
// reg[8:0] y_reg;

// wire in_box;
// assign in_box = (x > x_reg) & (x < x_reg + 10'd50) & (y > y_reg) & (y < y_reg + 9'd50);

// assign colorOut = in_box ? 12'd0 : colorData; // When in box color black

// always @(posedge clk25) begin
// if (BTNU & screenEnd) begin
// y_reg <= y_reg - 9'd5;
// end if (BTNL & screenEnd) begin
// x_reg <= x_reg - 10'd5;
// end if (BTNR & screenEnd) begin
// x_reg <= x_reg + 10'd5;
// end if (BTND & screenEnd) begin
// y_reg <= y_reg + 9'd5;
// end if (reset) begin
// 			x_reg <= 10'b0;
// 			y_reg <= 9'b0;
// 		end
// end

// // Quickly assign the output colors to their channels using concatenation
// assign {VGA_R, VGA_G, VGA_B} = colorOut;

// endmodule

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

    // Sprite position (move once per frame with buttons)
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

    // PS2 interface (receive only)
    wire [7:0] ps2_rx_data;
    wire ps2_read_data;
    wire ps2_busy;
    wire ps2_err;
    wire [7:0] ps2_tx_data;
    wire ps2_write_data;
    assign ps2_tx_data = 8'h00;
    assign ps2_write_data = 1'b0;

    Ps2Interface u_ps2 (
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .clk(clk),
        .rst(reset),
        .tx_data(ps2_tx_data),
        .write_data(ps2_write_data),
        .rx_data(ps2_rx_data),
        .read_data(ps2_read_data),
        .busy(ps2_busy),
        .err(ps2_err)
    );

    // Scan code -> ASCII lookup (ascii.mem)
    wire [7:0] ascii_from_scan;
    reg [7:0] scan_code_latched;
    reg lookup_pending;

    RAM #(
        .DEPTH(256),
        .DATA_WIDTH(8),
        .ADDRESS_WIDTH(8),
        .MEMFILE({FILES_PATH, "ascii.mem"})
    ) AsciiLUT (
        .clk(clk),
        .wEn(1'b0),
        .addr(scan_code_latched),
        .dataIn(8'h00),
        .dataOut(ascii_from_scan)
    );

    // Track current printable character from keyboard make codes.
    reg break_pending;
    reg extended_pending;
    reg [7:0] typed_ascii;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            scan_code_latched <= 8'h00;
            lookup_pending <= 1'b0;
            break_pending <= 1'b0;
            extended_pending <= 1'b0;
            typed_ascii <= 8'h41; // 'A' default
        end else begin
            if (lookup_pending) begin
                // Accept only normal make codes that map to printable ASCII.
                if (!break_pending && !extended_pending && (ascii_from_scan != 8'h00) &&
                    (ascii_from_scan >= 8'h21) && (ascii_from_scan <= 8'h7E)) begin
                    typed_ascii <= ascii_from_scan;
                end
                lookup_pending <= 1'b0;
                break_pending <= 1'b0;
                extended_pending <= 1'b0;
            end

            if (ps2_read_data) begin
                if (ps2_rx_data == 8'hF0) begin
                    break_pending <= 1'b1;
                end else if (ps2_rx_data == 8'hE0) begin
                    extended_pending <= 1'b1;
                end else begin
                    scan_code_latched <= ps2_rx_data;
                    lookup_pending <= 1'b1;
                end
            end
        end
    end

    // Sprite ROM addressing
    // Simple CDC into pixel clock domain for rendering logic.
    reg [7:0] typed_ascii_sync0;
    reg [7:0] typed_ascii_pix;
    always @(posedge clk25 or posedge reset) begin
        if (reset) begin
            typed_ascii_sync0 <= 8'h41;
            typed_ascii_pix <= 8'h41;
        end else begin
            typed_ascii_sync0 <= typed_ascii;
            typed_ascii_pix <= typed_ascii_sync0;
        end
    end

    wire printable_char;
    wire [6:0] sprite_index;
    assign printable_char = (typed_ascii_pix >= 8'h21) && (typed_ascii_pix <= 8'h7E);
    assign sprite_index = printable_char ? (typed_ascii_pix - 8'h21) : 7'd0;

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

    // Final color: sprite ROM is synchronous (1-cycle latency), so delay control/background by 1 pixel.
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
