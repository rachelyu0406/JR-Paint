`timescale 1 ns / 100 ps

module FinalProjectVGABehavioral(
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

    localparam VIDEO_WIDTH  = 640;
    localparam VIDEO_HEIGHT = 480;

    // Small drawing canvas
    localparam CELL_SIZE   = 8;
    localparam GRID_WIDTH  = 80;   // 640 / 8
    localparam GRID_HEIGHT = 60;   // 480 / 8
    localparam GRID_COUNT  = GRID_WIDTH * GRID_HEIGHT;
    localparam GRID_ADDR_W = $clog2(GRID_COUNT);

    // Cursor is 2x2 cells = 16x16 pixels on screen
    localparam CURSOR_SIZE = 2;
    localparam STEP        = 1;

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
    // Cursor position in grid coordinates
    // =========================================================
    reg [6:0] x_pos;
    reg [5:0] y_pos;

    reg [6:0] next_x;
    reg [5:0] next_y;

    always @(*) begin
        next_x = x_pos;
        next_y = y_pos;

        if (BTNU && (y_pos >= STEP))
            next_y = y_pos - STEP;
        else if (BTND && (y_pos + CURSOR_SIZE + STEP <= GRID_HEIGHT))
            next_y = y_pos + STEP;

        if (BTNL && (x_pos >= STEP))
            next_x = x_pos - STEP;
        else if (BTNR && (x_pos + CURSOR_SIZE + STEP <= GRID_WIDTH))
            next_x = x_pos + STEP;
    end

    // =========================================================
    // Small 1-bit canvas: 0 = white, 1 = black
    // =========================================================
    reg canvas [0:GRID_COUNT-1];
    reg canvas_pixel;

    integer i;
    initial begin
        for (i = 0; i < GRID_COUNT; i = i + 1)
            canvas[i] = 1'b0;
    end

    // Convert screen pixel coordinates to canvas cell coordinates
    wire [6:0] cell_x;
    wire [5:0] cell_y;
    assign cell_x = x[9:3]; // x / 8
    assign cell_y = y[8:3]; // y / 8

    wire [GRID_ADDR_W-1:0] read_addr;
    assign read_addr = cell_y * GRID_WIDTH + cell_x;

    // =========================================================
    // Clear canvas on reset
    // =========================================================
    reg clearing;
    reg [GRID_ADDR_W-1:0] clear_addr;

    // =========================================================
    // Paint cursor square into canvas so trail remains
    // =========================================================
    reg painting;
    reg [6:0] paint_base_x;
    reg [5:0] paint_base_y;
    reg [1:0] paint_dx;
    reg [1:0] paint_dy;

    wire [GRID_ADDR_W-1:0] paint_addr;
    assign paint_addr =
        (paint_base_y + paint_dy) * GRID_WIDTH +
        (paint_base_x + paint_dx);

    // =========================================================
    // Live cursor overlay
    // =========================================================
    wire inCursor;
    assign inCursor =
        (cell_x >= x_pos) && (cell_x < x_pos + CURSOR_SIZE) &&
        (cell_y >= y_pos) && (cell_y < y_pos + CURSOR_SIZE);

    // =========================================================
    // Canvas read/write
    // =========================================================
    always @(posedge clk25) begin
        // synchronous read for display
        canvas_pixel <= canvas[read_addr];

        // write priority: clear first, then paint
        if (clearing)
            canvas[clear_addr] <= 1'b0;
        else if (painting)
            canvas[paint_addr] <= 1'b1;
    end

    // =========================================================
    // Control state
    // =========================================================
    always @(posedge clk25 or posedge reset) begin
        if (reset) begin
            x_pos <= GRID_WIDTH / 2;
            y_pos <= GRID_HEIGHT / 2;

            clearing   <= 1'b1;
            clear_addr <= {GRID_ADDR_W{1'b0}};

            painting     <= 1'b0;
            paint_base_x <= 7'd0;
            paint_base_y <= 6'd0;
            paint_dx     <= 2'd0;
            paint_dy     <= 2'd0;
        end else begin
            if (clearing) begin
                if (clear_addr == GRID_COUNT - 1) begin
                    clearing <= 1'b0;

                    // paint initial cursor position after clear
                    painting     <= 1'b1;
                    paint_base_x <= x_pos;
                    paint_base_y <= y_pos;
                    paint_dx     <= 2'd0;
                    paint_dy     <= 2'd0;
                end else begin
                    clear_addr <= clear_addr + 1'b1;
                end
            end else if (painting) begin
                if (paint_dx == CURSOR_SIZE - 1) begin
                    paint_dx <= 2'd0;
                    if (paint_dy == CURSOR_SIZE - 1) begin
                        paint_dy <= 2'd0;
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

                    // paint the new cursor square into canvas
                    painting     <= 1'b1;
                    paint_base_x <= next_x;
                    paint_base_y <= next_y;
                    paint_dx     <= 2'd0;
                    paint_dy     <= 2'd0;
                end
            end
        end
    end

    // =========================================================
    // Final VGA color
    // =========================================================
    wire [11:0] colorOut;
    assign colorOut = active ? ((canvas_pixel || inCursor) ? BLACK : WHITE) : BLACK;

    assign {VGA_R, VGA_G, VGA_B} = colorOut;

    // PS/2 unused
    assign ps2_clk  = 1'bz;
    assign ps2_data = 1'bz;

endmodule