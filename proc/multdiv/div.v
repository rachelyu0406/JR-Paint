module div(out, exception, weReady, clk, reset, dividend, divisor);

    input clk, reset;
    input[31:0] dividend, divisor;
    output weReady, exception;
    output[31:0] out;

    wire[31:0] divisor_n , divisor_tn;
    wire[31:0] dividend_n, dividend_tn;
    wire[31:0] divisorPos_tn;
    wire[63:0] remainderQuotient, remainderQuotientShift, remainderQuotientNext, remainderQuotientNextReal;
    wire [5:0] count;
    wire done32;
    wire allZeroCount;
    wire[31:0] remainder;
    //sub = 0; add = 1
    wire addsubChoose;
    wire[31:0] divisor_chosen;
    wire[31:0] addSubRes;
    wire isResNeg;
    wire[31:0] res_n, res_tn;
    wire[31:0] finalOut;
    wire[31:0] divisorPos, dividendPos;

    //exception is when the divisor is 0
    //module comparator_32(A, B, EQ0, GT0);
    comparator_32 checkExcept(.A(divisor), .B(32'b0), .EQ0(exception), .GT0());

    //finding the twos complements of divisor and dividend
    assign divisor_n = ~(divisor);
    cla_level2 add1(.a(divisor_n), .b({{31{1'b0}},1'b1}), .s(divisor_tn), .cin(1'b0), .cout(), .last4());

    assign dividend_n = ~(dividend);
    cla_level2 add12(.a(dividend_n), .b({{31{1'b0}},1'b1}), .s(dividend_tn), .cin(1'b0), .cout(), .last4());

    //assign both always positive
    assign dividendPos = dividend[31] ? dividend_tn : dividend;
    assign divisorPos = divisor[31] ? divisor_tn : divisor;

    //find whats the negative bc divisor_tn may be positive if divisor is negative
    assign divisorPos_tn = divisor[31] ? divisor : divisor_tn;

    //module tff(Q, T, clk, en, clr);
    //ok counter yay
    tff t0(.Q(count[0]), .T(1'b1), .clk(clk), .en(1'b1), .clr(reset));
    tff t1(.Q(count[1]), .T(count[0]), .clk(clk), .en(1'b1), .clr(reset));
    tff t2(.Q(count[2]), .T(count[1] & count[0]), .clk(clk), .en(1'b1), .clr(reset));
    tff t3(.Q(count[3]), .T(count[2] & count[1] & count[0]), .clk(clk), .en(1'b1), .clr(reset));
    tff t4(.Q(count[4]), .T(count[3] & count[2] & count[1] & count[0]), .clk(clk), .en(1'b1), .clr(reset));
    tff t5(.Q(count[5]), .T(count[4] & count[3] & count[2] & count[1] & count[0]), .clk(clk), .en(1'b1), .clr(reset));

    //we did 32 cycles if count = 100000
    assign done32 = count[5] & !count[4] & !count[3] & !count[2] & !count[1] & !count[0];

    assign allZeroCount = !(|count);

    assign remainderQuotientNextReal[31:0] = allZeroCount ? dividendPos : remainderQuotientNext[31:0];
    assign remainderQuotientNextReal[63:32] = allZeroCount ? 32'b0 : remainderQuotientNext[63:32];

    register #(64) remainderQuotientReg(.out(remainderQuotient), .d(remainderQuotientNextReal), .clk(clk), .resetn(reset), .write_en(!done32));


    assign remainderQuotientShift = remainderQuotient << 1;

    assign remainderQuotientNext[31:1] = remainderQuotientShift[31:1];

    assign addsubChoose = remainderQuotient[63] ? 1'b0 : 1'b1;

    assign divisor_chosen = remainderQuotient[63] ? divisorPos : divisorPos_tn;

    cla_level2 addsub(.a(remainderQuotientShift[63:32]), .b(divisor_chosen), .s(remainderQuotientNext[63:32]), .cin(1'b0), .cout(), .last4());

    //0th bit set to 1 or 0 based on if msb is 0 or 1
    assign remainderQuotientNext[0] = remainderQuotientNext[63] ? 1'b0 : 1'b1;

    assign weReady = done32;

    //choose the negative if xor of dividend and divisor are neg
    assign isResNeg = (dividend[31] ^ divisor[31]); 
    
    assign res_n = ~(remainderQuotientNextReal[31:0]);

    cla_level2 add13(.a(res_n), .b({{31{1'b0}},1'b1}), .s(res_tn), .cin(1'b0), .cout(), .last4()); 
    
    assign finalOut = isResNeg ? res_tn : remainderQuotientNextReal[31:0];

    //turn this tristate on and make the result 0 only if we have an exception
    tristate divideExcept(.out(out), .in(32'b0), .en(exception));

    tristate divideNot(.out(out), .in(finalOut), .en(~exception));

endmodule