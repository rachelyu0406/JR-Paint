`timescale 1ns / 1ps
module PWMDeserializer #(
    parameter
    PERIOD_WIDTH_NS  = 100000,
    SYS_FREQ_MHZ   = 100) (
    input clk,
    input reset,
    input signal,
    output[9:0] duty_cycle);
    
    localparam PERIOD = (PERIOD_WIDTH_NS * SYS_FREQ_MHZ) / 1000;
    localparam PULSE_BITS  = $clog2(PERIOD) + 1;
    
    reg[PULSE_BITS-1:0] pulseCounter = 0;
    reg[PULSE_BITS-1:0] pulseWidth = 0;
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            pulseCounter <= 0;
            pulseWidth   <= 0;
        end else begin
            if(pulseCounter < PERIOD-1) begin
                pulseCounter <= pulseCounter + 1;
                pulseWidth   <= signal ? pulseWidth + 1 : pulseWidth;
            end else begin
                pulseCounter <= 0;
                pulseWidth   <= 0;
            end
        end
    end
    
    reg[PULSE_BITS-1:0] propWidth = 0;
    always @(negedge clk) begin
        if(pulseCounter == PERIOD-1)
            propWidth <= pulseWidth;
    end
    
    // << 10 is less accurate than * 1023 but more efficient 
    assign duty_cycle = (propWidth << 10) / (PERIOD - 1);  // Adjust for ending one cycle early on line 21
endmodule
