module cla_level2(a, b, s, cin, cout, last4);

    input[31:0] a, b;
    input cin;
    output[31:0] s;
    output cout;
    output last4;

    wire c8, c16, c24;
    wire P0, P1, P2, P3;
    wire G0, G1, G2, G3;

    wire d0, d1, d2, d3;

    wire last1, last2, last3;

    cla_8 one   (a[7:0],   b[7:0],   cin, d0, s[7:0],   P0, G0, last1);
    cla_8 two   (a[15:8],  b[15:8],  c8,  d1, s[15:8],  P1, G1, last2);
    cla_8 three (a[23:16], b[23:16], c16, d2, s[23:16], P2, G2, last3);
    cla_8 four  (a[31:24], b[31:24], c24, d3, s[31:24], P3, G3, last4);

    // C8  = G0 + P0*C0
    // C16 = G1 + P1*G0 + P1*P0*C0
    // C24 = G2 + P2*G1 + P2*P1*G0 + P2*P1*P0*C0
    // Cout= G3 + P3*G2 + P3*P2*G1 + P3*P2*P1*G0 + P3*P2*P1*P0*C0

    wire c8_t1;
    and (c8_t1, P0, cin);
    or  (c8, G0, c8_t1);

    wire c16_t1, c16_t2;
    and (c16_t1, P1, G0);
    and (c16_t2, P1, P0, cin);
    or  (c16, G1, c16_t1, c16_t2);

    wire c24_t1, c24_t2, c24_t3;
    and (c24_t1, P2, G1);
    and (c24_t2, P2, P1, G0);
    and (c24_t3, P2, P1, P0, cin);
    or  (c24, G2, c24_t1, c24_t2, c24_t3);

    wire cout_t1, cout_t2, cout_t3, cout_t4;
    and (cout_t1, P3, G2);
    and (cout_t2, P3, P2, G1);
    and (cout_t3, P3, P2, P1, G0);
    and (cout_t4, P3, P2, P1, P0, cin);
    or  (cout, G3, cout_t1, cout_t2, cout_t3, cout_t4);

endmodule
