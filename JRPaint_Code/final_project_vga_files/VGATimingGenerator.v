`timescale 1 ns / 1 ps

module VGATimingGenerator #(parameter HEIGHT = 480, WIDTH = 640) (
    input clk25,         // 25 MHz pixel clock
    input reset,         // Synchronous frame reset
    output active,       // High during the visible region
    output screenEnd,    // One-cycle pulse at the end of the frame
    output hSync,        // Horizontal sync
    output vSync,        // Vertical sync
    output [9:0] x,      // Visible x coordinate
    output [8:0] y       // Visible y coordinate
);

    // 640x480 @ 60 Hz VGA timing.
    localparam
        H_FRONT_PORCH = 16,
        H_SYNC_WIDTH  = 96,
        H_BACK_PORCH  = 48,

        H_SYNC_START = WIDTH + H_FRONT_PORCH,
        H_SYNC_END   = H_SYNC_START + H_SYNC_WIDTH,
        H_LINE       = H_SYNC_END + H_BACK_PORCH,

        V_FRONT_PORCH = 11,
        V_SYNC_WIDTH  = 2,
        V_BACK_PORCH  = 31,

        V_SYNC_START = HEIGHT + V_FRONT_PORCH,
        V_SYNC_END   = V_SYNC_START + V_SYNC_WIDTH,
        V_LINE       = V_SYNC_END + V_BACK_PORCH;

    reg [9:0] hPos = 0;
    reg [9:0] vPos = 0;

    always @(posedge clk25 or posedge reset) begin
        if (reset) begin
            hPos <= 0;
            vPos <= 0;
        end else begin
            if (hPos == H_LINE - 1) begin
                hPos <= 0;
                if (vPos == V_LINE - 1)
                    vPos <= 0;
                else
                    vPos <= vPos + 1;
            end else begin
                hPos <= hPos + 1;
            end
        end
    end

    wire activeX;
    wire activeY;

    assign activeX = (hPos < WIDTH);
    assign activeY = (vPos < HEIGHT);
    assign active = activeX & activeY;

    assign x = activeX ? hPos : 0;
    assign y = activeY ? vPos : 0;

    assign screenEnd = (vPos == (V_LINE - 1)) & (hPos == (H_LINE - 1));

    assign hSync = (hPos < H_SYNC_START) | (hPos >= H_SYNC_END);
    assign vSync = (vPos < V_SYNC_START) | (vPos >= V_SYNC_END);
endmodule
