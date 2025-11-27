module full_adder (
    input a,
    input b,
    input cin,
    output sum,
    output cout
);

    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));
endmodule

module bit8_full_adder(
    input [7:0] A,
    input [7:0] B,
    input Cin,
    output [7:0] Sum,
    output Cout
);
    wire [7:0] carry;

    full_adder FA0 (
        .a(A[0]),
        .b(B[0]),
        .cin(Cin),
        .sum(Sum[0]),
        .cout(carry[0])
    );
    genvar i;
    generate
        for (i = 1; i < 8; i = i + 1) begin : FA_LOOP
            full_adder FA (
                .a(A[i]),
                .b(B[i]),
                .cin(carry[i - 1]),
                .sum(Sum[i]),
                .cout(carry[i])
            );
        end
    endgenerate
    assign Cout = carry[7];

endmodule

module bit_manipulator(
    input Aprev,
    input Anext,
    input direction,
    output ai
);
    wire rightSide, leftSide;

    and (rightSide, Anext, direction);
    and (leftSide, Aprev, ~direction);
    or (ai, rightSide, leftSide);
endmodule

module bit8_manipulator(
    input [7:0] A,
    input direction, // 0 for left, 1 for right
    input rotate,
    output [7:0] Out
);

    wire [7:0] temp;
    
    genvar j;
    generate
        for (j = 1; j < 7; j = j + 1) begin : BM_LOOP
            bit_manipulator BM (
                .Aprev(A[j - 1]),
                .Anext(A[j + 1]),
                .direction(direction),
                .ai(temp[j])
            );
        end

        wire leftmost, rightmost;
        and (rightmost, A[7], rotate, ~direction);

        wire c1, c2;

        and(c1, ~rotate, direction, A[7]);
        and(c2, rotate, direction, A[0]);

        or (leftmost, c1, c2);

        bit_manipulator BM_leftmost (
            .Aprev(A[6]),
            .Anext(leftmost),
            .direction(direction),
            .ai(temp[7])
        );

        bit_manipulator BM_rightmost (
            .Aprev(rightmost),
            .Anext(A[1]),
            .direction(direction),
            .ai(temp[0])
        );
    endgenerate

    assign Out = temp;
endmodule


module mux2to1(
    input sel,
    input in0,
    input in1,
    output out
);

    wire not_sel, and0, and1;

    not (not_sel, sel);
    and (and0, in0, not_sel);
    and (and1, in1, sel);
    or  (out, and0, and1);
    
endmodule

module mux4to1(
    input [1:0] sel,
    input [3:0] in,
    output out
);

    wire mux0_out, mux1_out;

    mux2to1 mux0 (
        .sel(sel[0]),
        .in0(in[0]),
        .in1(in[1]),
        .out(mux0_out)
    );

    mux2to1 mux1 (
        .sel(sel[0]),
        .in0(in[2]),
        .in1(in[3]),
        .out(mux1_out)
    );

    mux2to1 mux_final (
        .sel(sel[1]),
        .in0(mux0_out),
        .in1(mux1_out),
        .out(out)
    );
    
endmodule

module mux8to1(
    input [2:0] sel,
    input [7:0] in,
    output out
);

    wire mux0_out, mux1_out;

    mux4to1 mux0 (
        .sel(sel[1:0]),
        .in(in[3:0]),
        .out(mux0_out)
    );

    mux4to1 mux1 (
        .sel(sel[1:0]),
        .in(in[7:4]),
        .out(mux1_out)
    );

    mux2to1 mux_final (
        .sel(sel[2]),
        .in0(mux0_out),
        .in1(mux1_out),
        .out(out)
    );
endmodule

module mux16to1(
    input [3:0] sel,
    input [15:0] in,
    output out
);

    wire mux0_out, mux1_out;

    mux8to1 mux0 (
        .sel(sel[2:0]),
        .in(in[7:0]),
        .out(mux0_out)
    );

    mux8to1 mux1 (
        .sel(sel[2:0]),
        .in(in[15:8]),
        .out(mux1_out)
    );

    mux2to1 mux_final (
        .sel(sel[3]),
        .in0(mux0_out),
        .in1(mux1_out),
        .out(out)
    );
endmodule
 
module ALU_8 (output [7:0] Result, output Zero, Negative, Overflow,
input [7:0] A, B, input [3:0] AluOp);

    wire [7:0] A_to_FA;

    genvar k;
    generate
        for (k = 0; k < 8; k = k + 1) begin : INVERT_A_LOOP
            mux2to1 MUX_INVERT_A (
                .sel(AluOp[0]),
                .in0(A[k]),
                .in1(~A[k]),
                .out(A_to_FA[k])
            );
        end
    endgenerate

    wire [7:0] B_to_FA;

    wire [7:0] C = 8'b00000001;

    genvar m;
    generate
        for (m = 0; m < 8; m = m + 1) begin : SET_B_OR_C
            mux2to1 MUX_INVERT_B (
                .sel(AluOp[1]),
                .in0(B[m]),
                .in1(C[m]),
                .out(B_to_FA[m])
            );
        end
    endgenerate

    wire[7:0] Sum;
    wire Cout;

    bit8_full_adder ADDER (
        .A(A_to_FA),
        .B(B_to_FA),
        .Cin(AluOp[0]),
        .Sum(Sum),
        .Cout(Cout)
    );

    assign Overflow = 
        (AluOp == 4'b0000 && ((A[7] == B[7]) && (Sum[7] != A[7]))) ||
        (AluOp == 4'b0001 && ((A[7] != B[7]) && (Sum[7] != B[7]))) ||
        (AluOp == 4'b0010 && ((A[7] == 0) && (Sum[7] != 0))); 

    wire [7:0] A_B_To_Manipulator;

    genvar l;

    generate
        for (l = 0; l < 8; l = l + 1) begin : PASS_THROUGH_LOOP
            mux2to1 MUX_PASS_THROUGH (
                .sel(AluOp[3]),
                .in0(B[l]),
                .in1(A[l]),
                .out(A_B_To_Manipulator[l])
            );
        end
    endgenerate

    wire [7:0] Manipulated_Result;

    bit8_manipulator MANIPULATOR (
        .A(A_B_To_Manipulator),
        .direction(AluOp[0]),
        .rotate(AluOp[3]),
        .Out(Manipulated_Result)
    );


    wire [7:0] AorB;
    genvar n;
    generate
        for (n = 0; n < 8; n = n + 1) begin : OR_LOOP
            or (AorB[n], A[n], B[n]);
        end
    endgenerate

    wire [7:0] AandB;
    genvar p;
    generate
        for (p = 0; p < 8; p = p + 1) begin : AND_LOOP
            and (AandB[p], A[p], B[p]);
        end
    endgenerate

    wire [7:0] AequalB, AequalB_bit;
    genvar r;
    generate
        for (r = 0; r < 8; r = r + 1) begin : EQUAL_LOOP
            xnor (AequalB_bit[r], A[r], B[r]);
        end

        wire temp_equal;
        assign temp_equal = &AequalB_bit;

        genvar s;
        generate
            for (s = 0; s < 7; s = s + 1) begin : FINAL_EQUAL_LOOP
                assign AequalB[7-s] = 0;
            end
            assign AequalB[0] = temp_equal;
        endgenerate

    endgenerate

    genvar q;
    generate
        for (q = 0; q < 8; q = q + 1) begin : RESULT_MUX_LOOP
            mux16to1 RESULT_MUX (
                .sel(AluOp),
                .in({
                    1'b0,
                    1'b0,
                    Manipulated_Result[q],
                    Manipulated_Result[q],
                    ~AandB[q],
                    AorB[q],
                    AandB[q],
                    ~A[q],
                    Manipulated_Result[q],
                    Manipulated_Result[q],
                    AequalB[q],
                    1'b0, 
                    1'b0,
                    Sum[q], 
                    Sum[q],
                    Sum[q]
                }),
                .out(Result[q])
            );
        end
    endgenerate

    assign Zero = ~(Result[0] | Result[1] | Result[2] | Result[3] | Result[4] | Result[5] | Result[6] | Result[7]);
    assign Negative = Result[7];

endmodule