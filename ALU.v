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
    wire [6:0] carry;

    full_adder FA0 (
        .a(A[0]),
        .b(B[0]),
        .cin(Cin),
        .sum(Sum[0]),
        .cout(carry[0])
    );

    genvar i;
    generate
        for (i = 1; i < 7; i = i + 1) begin : FA_LOOP
            full_adder FA (
                .a(A[i]),
                .b(B[i]),
                .cin(carry[i-1]),
                .sum(Sum[i]),
                .cout(carry[i])
            );
        end
    endgenerate

    full_adder FA7 (
        .a(A[7]),
        .b(B[7]),
        .cin(carry[6]),
        .sum(Sum[7]),
        .cout(Cout)
    );
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
        wire rotate_l, rotate_r;

        and (rotate_r, ~direction, rotate);
        and (rotate_l, direction, rotate);

        and (rightmost, A[7], rotate_r);
        and (leftmost,  A[0], rotate_l);
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
                .sel(AluOp[3]),
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
        for (m = 0; m < 8; m = m + 1) begin : INVERT_B_LOOP
            mux2to1 MUX_INVERT_B (
                .sel(AluOp[2]),
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

    assign Overflow = Cout & (~AluOp[1] & ~AluOp[2] & AluOp[3]);

    wire [7:0] A_B_To_Manipulator;

    mux2to1 MUX_A_B (
        .sel(AluOp[3]),
        .in0(A),
        .in1(B),
        .out(A_B_To_Manipulator)
    );

    wire [7:0] Manipulated_Result;

    bit8_manipulator MANIPULATOR (
        .A(A_B_To_Manipulator),
        .direction(AluOp[0]),
        .rotate(AluOp[1]),
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

    wire [7:0] AequalB;
    genvar r;
    generate
        for (r = 0; r < 8; r = r + 1) begin : EQUAL_LOOP
            xor (AequalB[r], A[r], B[r]);
            not (AequalB[r], AequalB[r]);
        end
    endgenerate

    genvar q;
    generate
        for (q = 0; q < 8; q = q + 1) begin : RESULT_MUX_LOOP
            mux16to1 RESULT_MUX (
                .sel(AluOp),
                .in({
                    Sum[q], 
                    Sum[q], 
                    Sum[q], 
                    1'b0, 
                    1'b0, 
                    AequalB[q],
                    Manipulated_Result[q],
                    Manipulated_Result[q],
                    ~A[q],
                    AandB[q],
                    AorB[q],
                    ~AandB[q],
                    1'b0,
                    Manipulated_Result[q],
                    Manipulated_Result[q],
                    1'b0,
                    1'b0
                    }),
                .out(Result[q])
            );
        end
    endgenerate


endmodule