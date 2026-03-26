module alu (data_operandA, data_operandB, ctrl_ALUopcode, ctrl_shiftamt, data_result, isNotEqual, isLessThan, overflow);
    
    input [31:0] data_operandA, data_operandB;
    input [4:0] ctrl_ALUopcode, ctrl_shiftamt;

    wire cin, cout, last;

    output [31:0] data_result;

    output isNotEqual, isLessThan, overflow;

    wire [31:0] nottedB;

    wire [31:0] finDes;

    wire [31:0] addsubRes, orRes, andRes, notRes, sllRes, sraRes;

    //choosing if we want subtraction or addition
    assign cin = ctrl_ALUopcode[0] ? 1 : 0;

    not_32 inverse(nottedB, data_operandB);

    //i need to not the sub if we are subbing
    assign finDes = ctrl_ALUopcode[0] ? nottedB : data_operandB;
    
    cla_level2 addsub(data_operandA, finDes, addsubRes, cin, cout, last);

    xor(overflow, cout, last);

    wire[31:0] subRes;

    //cla_level2(a, b, s, cin, cout, last4);
    cla_level2 sub(.a(data_operandA), .b(nottedB), .s(subRes), .cin(1'b1));

    //handle islessthan and isnotequal
    xor(isLessThan, subRes[31], overflow);

    notEqual_32 check(isNotEqual, data_operandA, data_operandB);

    //handle the or, and sll, etc
    or_32 orOp(orRes, data_operandA, data_operandB);

    and_32 andOp(andRes, data_operandA, data_operandB);

    sll sllOp(sllRes, data_operandA, ctrl_shiftamt);

    sra sraOp(sraRes, data_operandA, ctrl_shiftamt);

    mux_8 #(32)
        opChoose(data_result, ctrl_ALUopcode[2:0], addsubRes, addsubRes, andRes, orRes, sllRes, sraRes, 32'b0, 32'b0);

endmodule