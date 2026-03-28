module multdiv(
    data_operandA, data_operandB, 
    ctrl_MULT, ctrl_DIV, 
    clock, 
    data_result, data_exception, data_resultRDY);

    input [31:0] data_operandA, data_operandB;
    input ctrl_MULT, ctrl_DIV, clock;

    output [31:0] data_result;
    output data_exception, data_resultRDY;

    wire [31:0] data_out_mult;
    wire [31:0] data_out_div;
    wire exceptionMult, exceptionDiv, multReady, divReady;
    wire chooseMultDiv;
    
    // track if we're actively doing mult or div
    wire multActive, divActive;
    wire multActive_next, divActive_next;
    
    assign multActive_next = ctrl_MULT ? 1'b1 : (multReady ? 1'b0 : multActive);
    dffe_ref multActiveReg(.q(multActive), .d(multActive_next), .clk(clock), .en(1'b1), .clr(1'b0));
    
    assign divActive_next = ctrl_DIV ? 1'b1 : (divReady ? 1'b0 : divActive);
    dffe_ref divActiveReg(.q(divActive), .d(divActive_next), .clk(clock), .en(1'b1), .clr(1'b0));

    mult myMultiplier(.out(data_out_mult), .overflow(exceptionMult), .weReady(multReady), 
                      .clk(clock), .reset(~multActive), .plicand(data_operandA), .plier(data_operandB));

    div myDiv(.out(data_out_div), .exception(exceptionDiv), .weReady(divReady), 
              .clk(clock), .reset(~divActive), .dividend(data_operandA), .divisor(data_operandB));

    dffe_ref choose(.q(chooseMultDiv), .d(1'b1), .clk(clock), .en(ctrl_MULT), .clr(ctrl_DIV));

    assign data_result = chooseMultDiv ? data_out_mult : data_out_div;
    assign data_exception = chooseMultDiv ? exceptionMult : exceptionDiv;
    assign data_resultRDY = (multActive & multReady) | (divActive & divReady);

endmodule