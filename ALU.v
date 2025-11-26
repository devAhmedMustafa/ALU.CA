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

module mux12to1(
    input [3:0] sel,
    input [15:0] in,
    output out
);

    
    
endmodule