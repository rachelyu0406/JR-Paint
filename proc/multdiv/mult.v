module mult(out, overflow, weReady, clk, reset, plicand, plier);

    input clk, reset;
    input[31:0] plicand, plier;
    output[31:0] out;
    output overflow, weReady;

    wire[65:0] prod;
    wire[65:0] prod_next;
    wire[32:0] addValue;
    wire[31:0] plicand_n, plicand_tn;
    wire cout;
    wire [31:0] count_d, count_out, count_outadd;
    wire done16;
    wire [32:0] resAdd;
    wire [65:0] prod_nextreal;

    wire[32:0] plicandsx, plicand_tnsx;

    wire allZeroCount;

    assign plicandsx = {plicand[31], plicand};

    //making plicand_tn the 2s complement of plicand
    assign plicand_n = ~(plicand);
    cla_level2 add1(.a(plicand_n), .b({{31{1'b0}},1'b1}), .s(plicand_tn), .cin(1'b0), .cout(), .last4());

    //sign extended the 2s complement
    assign plicand_tnsx = {plicand_tn[31], plicand_tn};

    //counting register
    register countReg(.out(count_out), .d(count_d), .clk(clk), .resetn(reset), .write_en(1'b1));

    assign allZeroCount = !(|count_out);

    //if the counter is all 0 reinitialize everything
    assign prod_nextreal[32:1] = allZeroCount ? plier : prod_next[32:1];
    assign prod_nextreal[65:33] = allZeroCount ? 33'b0 : prod_next[65:33];
    assign prod_nextreal[0] = allZeroCount ? 1'b0 : prod_next[0];

    //we are done if count_out is 10000
    assign done16 = count_out[4] & !count_out[3] & !count_out[2] & !count_out[1] & !count_out[0];

    cla_level2 counterAdd1(.a(count_out), .b({{31{1'b0}},1'b1}), .s(count_outadd), .cin(1'b0), .cout(), .last4());

    assign count_d = done16 ? count_out : count_outadd;

    //figure out which addvalue we need to choose
    mux_8 #(33) choose(addValue, prod[2:0], 33'b0, plicandsx, plicandsx, plicandsx << 1, plicand_tnsx << 1, plicand_tnsx, plicand_tnsx, 33'b0);

    //add top 32 bits
    cla_level2 addProd(.a(addValue[31:0]), .b(prod[64:33]), .s(resAdd[31:0]), .cin(1'b0), .cout(cout), .last4());

    //add for the last 66th bit, ignore carry out of this
    xor(resAdd[32], addValue[32], prod[65], cout);

    //arithmetic right shift by 2
    wire signed[65:0] prod_temp = {resAdd, prod[32:0]};
    assign prod_next = (prod_temp) >>> 2;

    //product register
    register #(66) prodReg(.out(prod), .d(prod_nextreal), .clk(clk), .resetn(reset), .write_en(!done16));

    assign weReady = done16;

    //wire[64:33] debug1 = {32{prod_nextreal[32]}};
    //wire[64:33] debug2 = prod_nextreal[64:33];
    //overflow if the top 33 bits are the same as the sign bit of the product
    //also special case if like -maxNum * -1 because one less + num than - num
    //if something is the smallest number = {1'b1, 31'b0}, -1 is {32'b1}
    wire special;
    assign special = ((plicand[31] & ~(|plicand[30:0])) & (&plier)) | ((plier[31] & ~(|plier[30:0])) & (&plicand));

    assign overflow = special | (|(prod_nextreal[65:33] ^ {33{prod_nextreal[32]}}));

    assign out = prod_nextreal[32:1];

endmodule