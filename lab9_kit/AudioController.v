module AudioController(
    input        clk, 		// System Clock Input 100 Mhz
    output servoSignal,
    input        micData,	// Microphone Output
    input[9:0]   switches,	// Tone control switches
    output reg   micClk = 0, 	// Mic clock 
    output       chSel,		// Channel select; 0 for rising edge, 1 for falling edge
    output       audioOut,	// PWM signal to the audio jack	
    output       audioEn);	// Audio Enable

	localparam MHz = 1000000;
	localparam SYSTEM_FREQ = 100*MHz; // System clock frequency

	assign chSel   = 1'b0;  // Collect Mic Data on the rising edge 
	assign audioEn = 1'b1;  // Enable Audio Output

	// Initialize the frequency array. FREQs[0] = 261
	reg[10:0] FREQs[0:15];
	initial begin
		$readmemh("FREQs.mem", FREQs);
	end
	
	////////////////////
	// Your Code Here //
	////////////////////

	
	wire[17:0] selected_freq;
	 reg[17:0] freq_count;
	always @(posedge clk) begin
		freq_count <= 1 * switches[0] + 2 * switches[1] + 4 * switches[2] + 8 * switches[3];
	end

	assign selected_freq = FREQs[freq_count];

reg [31:0] counter_limit;
always @(*) begin
    if (selected_freq != 0)
        counter_limit = SYSTEM_FREQ / (2 * selected_freq) - 1;
    else
        counter_limit = 0;
end
	reg pwmClk = 0;
	reg[17:0] counter = 0;
	always @(posedge clk) begin
		if (counter < counter_limit)
			counter <= counter + 1;
		else begin
			counter <= 0;
			pwmClk <= ~pwmClk;
		end
	end
	assign audioOut = pwmClk;

endmodule