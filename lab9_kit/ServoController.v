module ServoController(
    input        clk,         // 100 MHz
    input [9:0]  switches,
    input        BTNU,
    output       servoSignal
);

    reg [1:0] currentState = 2'b00;
    reg [9:0] dutyCycle;

    // Synchronize button into clk domain
    reg btn_ff0 = 0;
    reg btn_ff1 = 0;
    reg btn_ff2 = 0;

    always @(posedge clk) begin
        btn_ff0 <= BTNU;
        btn_ff1 <= btn_ff0;
        btn_ff2 <= btn_ff1;
    end

    wire btn_rise = btn_ff1 & ~btn_ff2;

    // Advance state once per button press
    always @(posedge clk) begin
        if (btn_rise)
            currentState <= currentState + 1'b1;
    end

    // Servo positions
    always @(*) begin
        case (currentState)
            2'b00: dutyCycle = 10'd51;   // ~1.0 ms
            2'b01: dutyCycle = 10'd77;   // ~1.5 ms
            2'b10: dutyCycle = 10'd102;  // ~2.0 ms
            default: dutyCycle = 10'd77;
        endcase
    end
    	
	PWMSerializer pwm_thing(clk, 1'b0, dutyCycle, servoSignal);
	
	
    
endmodule