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

    localparam VIDEO_WIDTH   = 640;
    localparam VIDEO_HEIGHT  = 480;
    localparam PIXEL_COUNT   = VIDEO_WIDTH * VIDEO_HEIGHT;
    localparam ADDR_WIDTH    = $clog2(PIXEL_COUNT);

    localparam CURSOR_SIZE = 10;
    localparam STEP        = 4;

    localparam [11:0] WHITE = 12'hFFF;
    localparam [11:0] BLACK = 12'h000;

    // 100 MHz -> 25 MHz pixel clock
    wire clk25;
    wire locked;

    clk_wiz_0 pll (
        .clk_out1(clk25),
        .reset(reset),
        .locked(locked),
        .clk_in1(clk)
    );

    // VGA timing
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

    // =========================================================
    // Cursor position
    // =========================================================
    reg [9:0] x_pos;
    reg [8:0] y_pos;

    reg [9:0] next_x;
    reg [8:0] next_y;

    always @(*) begin
        next_x = x_pos;
        next_y = y_pos;

        if (BTNU && (y_pos >= STEP))
            next_y = y_pos - STEP;
        else if (BTND && (y_pos + CURSOR_SIZE + STEP <= VIDEO_HEIGHT))
            next_y = y_pos + STEP;

        if (BTNL && (x_pos >= STEP))
            next_x = x_pos - STEP;
        else if (BTNR && (x_pos + CURSOR_SIZE + STEP <= VIDEO_WIDTH))
            next_x = x_pos + STEP;
    end

    // =========================================================
    // 1-bit framebuffer: 0 = white, 1 = black
    // =========================================================
    reg framebuf [0:PIXEL_COUNT-1];
    reg fb_pixel;

    integer i;
    initial begin
        for (i = 0; i < PIXEL_COUNT; i = i + 1)
            framebuf[i] = 1'b0;
    end

    wire [ADDR_WIDTH-1:0] read_addr;
    assign read_addr = x + VIDEO_WIDTH * y;

    // =========================================================
    // Clear framebuffer on reset
    // =========================================================
    reg clearing;
    reg [ADDR_WIDTH-1:0] clear_addr;

    // =========================================================
    // Paint cursor square into framebuffer so trail remains
    // =========================================================
    reg painting;
    reg [9:0] paint_base_x;
    reg [8:0] paint_base_y;
    reg [5:0] paint_dx;
    reg [5:0] paint_dy;

    wire [ADDR_WIDTH-1:0] paint_addr;
    assign paint_addr =
        (paint_base_y + paint_dy) * VIDEO_WIDTH +
        (paint_base_x + paint_dx);

    // =========================================================
    // Live cursor overlay
    // =========================================================
    wire inCursor;
    assign inCursor =
        (x >= x_pos) && (x < x_pos + CURSOR_SIZE) &&
        (y >= y_pos) && (y < y_pos + CURSOR_SIZE);

    // =========================================================
    // Framebuffer read/write
    // =========================================================
    always @(posedge clk25) begin
        // synchronous read for display
        fb_pixel <= framebuf[read_addr];

        // write priority: clear first, then paint
        if (clearing)
            framebuf[clear_addr] <= 1'b0;
        else if (painting)
            framebuf[paint_addr] <= 1'b1;
    end

    // =========================================================
    // Control state
    // =========================================================
    always @(posedge clk25 or posedge reset) begin
        if (reset) begin
            x_pos      <= VIDEO_WIDTH  / 2;
            y_pos      <= VIDEO_HEIGHT / 2;

            clearing   <= 1'b1;
            clear_addr <= {ADDR_WIDTH{1'b0}};

            painting   <= 1'b0;
            paint_base_x <= 10'd0;
            paint_base_y <= 9'd0;
            paint_dx   <= 6'd0;
            paint_dy   <= 6'd0;
        end else begin
            if (clearing) begin
                if (clear_addr == PIXEL_COUNT - 1) begin
                    clearing <= 1'b0;

                    // paint initial cursor position after clear
                    painting     <= 1'b1;
                    paint_base_x <= x_pos;
                    paint_base_y <= y_pos;
                    paint_dx     <= 6'd0;
                    paint_dy     <= 6'd0;
                end else begin
                    clear_addr <= clear_addr + 1'b1;
                end
            end else if (painting) begin
                if (paint_dx == CURSOR_SIZE - 1) begin
                    paint_dx <= 6'd0;
                    if (paint_dy == CURSOR_SIZE - 1) begin
                        paint_dy <= 6'd0;
                        painting <= 1'b0;
                    end else begin
                        paint_dy <= paint_dy + 1'b1;
                    end
                end else begin
                    paint_dx <= paint_dx + 1'b1;
                end
            end else if (screenEnd) begin
                if ((next_x != x_pos) || (next_y != y_pos)) begin
                    x_pos <= next_x;
                    y_pos <= next_y;

                    // paint the new cursor square into memory
                    painting     <= 1'b1;
                    paint_base_x <= next_x;
                    paint_base_y <= next_y;
                    paint_dx     <= 6'd0;
                    paint_dy     <= 6'd0;
                end
            end
        end
    end

    // =========================================================
    // Final VGA color
    // Show black if:
    //   - pixel already stored in framebuffer, or
    //   - pixel is inside current live cursor
    // Otherwise white
    // =========================================================
    wire [11:0] colorOut;
    assign colorOut = active ? ((fb_pixel || inCursor) ? BLACK : WHITE) : BLACK;

    assign {VGA_R, VGA_G, VGA_B} = colorOut;

    // PS/2 unused
    assign ps2_clk  = 1'bz;
    assign ps2_data = 1'bz;

endmodule