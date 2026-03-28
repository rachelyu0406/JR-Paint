module tff(Q, T, clk, en, clr);

    input clk, en, clr, T;
    wire T_n, q_d, q_nd;
    wire and1, and2, inD;
    output Q;

    assign T_n = ~(T);
    assign q_nd = ~(q_d);
    
    and(and1, T_n, q_d);
    and(and2, T, q_nd);
    or(inD, and1, and2);

    //module dffe_ref (q, d, clk, en, clr);
    dffe_ref idk(.q(q_d), .d(inD), .clk(clk), .en(en), .clr(clr));

    assign Q = q_d;

endmodule