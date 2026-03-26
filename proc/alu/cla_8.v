module cla_8(a, b, c0, c8, s, P, G, last);
    input[7:0] a, b;
    input c0;
    output c8, P, G;
    output[7:0] s;
    output last;

    wire p0,p1,p2,p3,p4,p5,p6,p7;
    wire g0,g1,g2,g3,g4,g5,g6,g7;

    wire c1,c2,c3,c4,c5,c6,c7;

    or  (p0, a[0], b[0]);
    or  (p1, a[1], b[1]);
    or  (p2, a[2], b[2]);
    or  (p3, a[3], b[3]);
    or  (p4, a[4], b[4]);
    or  (p5, a[5], b[5]);
    or  (p6, a[6], b[6]);
    or  (p7, a[7], b[7]);

    and (g0, a[0], b[0]);
    and (g1, a[1], b[1]);
    and (g2, a[2], b[2]);
    and (g3, a[3], b[3]);
    and (g4, a[4], b[4]);
    and (g5, a[5], b[5]);
    and (g6, a[6], b[6]);
    and (g7, a[7], b[7]);

    // c1 = g0 + p0 c0
    wire c1_t1;
    and (c1_t1, p0, c0);
    or  (c1, g0, c1_t1);

    // c2 = g1 + p1 g0 + p1 p0 c0
    wire c2_t1, c2_t2;
    and (c2_t1, p1, g0);
    and (c2_t2, p1, p0, c0);
    or  (c2, g1, c2_t1, c2_t2);

    // c3 = g2 + p2 g1 + p2 p1 g0 + p2 p1 p0 c0
    wire c3_t1, c3_t2, c3_t3;
    and (c3_t1, p2, g1);
    and (c3_t2, p2, p1, g0);
    and (c3_t3, p2, p1, p0, c0);
    or  (c3, g2, c3_t1, c3_t2, c3_t3);

    // c4 = g3 + p3 g2 + p3 p2 g1 + p3 p2 p1 g0 + p3 p2 p1 p0 c0
    wire c4_t1, c4_t2, c4_t3, c4_t4;
    and (c4_t1, p3, g2);
    and (c4_t2, p3, p2, g1);
    and (c4_t3, p3, p2, p1, g0);
    and (c4_t4, p3, p2, p1, p0, c0);
    or  (c4, g3, c4_t1, c4_t2, c4_t3, c4_t4);

    // c5 = g4 + p4 g3 + p4 p3 g2 + p4 p3 p2 g1 + p4 p3 p2 p1 g0 + p4 p3 p2 p1 p0 c0
    wire c5_t1, c5_t2, c5_t3, c5_t4, c5_t5;
    and (c5_t1, p4, g3);
    and (c5_t2, p4, p3, g2);
    and (c5_t3, p4, p3, p2, g1);
    and (c5_t4, p4, p3, p2, p1, g0);
    and (c5_t5, p4, p3, p2, p1, p0, c0);
    or  (c5, g4, c5_t1, c5_t2, c5_t3, c5_t4, c5_t5);

    // c6 = g5 + p5 g4 + p5 p4 g3 + p5 p4 p3 g2 + p5 p4 p3 p2 g1 + p5 p4 p3 p2 p1 g0 + p5 p4 p3 p2 p1 p0 c0
    wire c6_t1, c6_t2, c6_t3, c6_t4, c6_t5, c6_t6;
    and (c6_t1, p5, g4);
    and (c6_t2, p5, p4, g3);
    and (c6_t3, p5, p4, p3, g2);
    and (c6_t4, p5, p4, p3, p2, g1);
    and (c6_t5, p5, p4, p3, p2, p1, g0);
    and (c6_t6, p5, p4, p3, p2, p1, p0, c0);
    or  (c6, g5, c6_t1, c6_t2, c6_t3, c6_t4, c6_t5, c6_t6);

    // c7 = g6 + p6 g5 + p6 p5 g4 + p6 p5 p4 g3 + p6 p5 p4 p3 g2 + p6 p5 p4 p3 p2 g1 + p6 p5 p4 p3 p2 p1 g0 + p6 p5 p4 p3 p2 p1 p0 c0
    wire c7_t1, c7_t2, c7_t3, c7_t4, c7_t5, c7_t6, c7_t7;
    and (c7_t1, p6, g5);
    and (c7_t2, p6, p5, g4);
    and (c7_t3, p6, p5, p4, g3);
    and (c7_t4, p6, p5, p4, p3, g2);
    and (c7_t5, p6, p5, p4, p3, p2, g1);
    and (c7_t6, p6, p5, p4, p3, p2, p1, g0);
    and (c7_t7, p6, p5, p4, p3, p2, p1, p0, c0);
    or  (c7, g6, c7_t1, c7_t2, c7_t3, c7_t4, c7_t5, c7_t6, c7_t7);


    wire c8_t1, c8_t2, c8_t3, c8_t4, c8_t5, c8_t6, c8_t7, c8_t8;
    and (c8_t1, p7, g6);
    and (c8_t2, p7, p6, g5);
    and (c8_t3, p7, p6, p5, g4);
    and (c8_t4, p7, p6, p5, p4, g3);
    and (c8_t5, p7, p6, p5, p4, p3, g2);
    and (c8_t6, p7, p6, p5, p4, p3, p2, g1);
    and (c8_t7, p7, p6, p5, p4, p3, p2, p1, g0);
    and (c8_t8, p7, p6, p5, p4, p3, p2, p1, p0, c0);
    or  (c8, g7, c8_t1, c8_t2, c8_t3, c8_t4, c8_t5, c8_t6, c8_t7, c8_t8);

    //sum
    xor (s[0], a[0], b[0], c0);
    xor (s[1], a[1], b[1], c1);
    xor (s[2], a[2], b[2], c2);
    xor (s[3], a[3], b[3], c3);
    xor (s[4], a[4], b[4], c4);
    xor (s[5], a[5], b[5], c5);
    xor (s[6], a[6], b[6], c6);
    xor (s[7], a[7], b[7], c7);

    // P = p7 p6 p5 p4 p3 p2 p1 p0
    and (P, p7, p6, p5, p4, p3, p2, p1, p0);

    //
    // G = g7 + p7 g6 + p7 p6 g5 + p7 p6 p5 g4 + p7 p6 p5 p4 g3 + p7 p6 p5 p4 p3 g2 + p7 p6 p5 p4 p3 p2 g1 + p7 p6 p5 p4 p3 p2 p1 g0
    wire G1, G2, G3, G4, G5, G6, G7;
    and (G1, p7, g6);
    and (G2, p7, p6, g5);
    and (G3, p7, p6, p5, g4);
    and (G4, p7, p6, p5, p4, g3);
    and (G5, p7, p6, p5, p4, p3, g2);
    and (G6, p7, p6, p5, p4, p3, p2, g1);
    and (G7, p7, p6, p5, p4, p3, p2, p1, g0);
    or  (G, g7, G1, G2, G3, G4, G5, G6, G7);

    assign last = c7;

endmodule
