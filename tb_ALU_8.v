`timescale 1ns/1ps

module tb_ALU_8;
    reg [7:0] A;
    reg [7:0] B;
    reg [3:0] AluOp;
    wire [7:0] Result;
    wire Zero, Negative, Overflow;

    ALU_8 dut (
        .Result(Result),
        .Zero(Zero),
        .Negative(Negative),
        .Overflow(Overflow),
        .A(A),
        .B(B),
        .AluOp(AluOp)
    );

    integer i;
    integer failures;

    task compute_expected(
        input [7:0] a, input [7:0] b, input [3:0] op,
        output [7:0] exp_res, output exp_zero, output exp_neg, output exp_ovf
    );
        integer signed_tmp;
        begin
            exp_ovf = 0;
            case (op)
                4'b0000: begin // A + B
                    signed_tmp = $signed(a) + $signed(b);
                    exp_res = signed_tmp[7:0];
                    exp_ovf = (signed_tmp > 127) || (signed_tmp < -128);
                end
                4'b0001: begin // B - A
                    signed_tmp = $signed(b) - $signed(a);
                    exp_res = signed_tmp[7:0];
                    exp_ovf = (signed_tmp > 127) || (signed_tmp < -128);
                end
                4'b0010: begin // A + 1
                    signed_tmp = $signed(a) + 1;
                    exp_res = signed_tmp[7:0];
                    exp_ovf = (signed_tmp > 127) || (signed_tmp < -128);
                end
                4'b0101: begin // A == B
                    exp_res = (a == b) ? 8'b00000001 : 8'b00000000;
                end
                4'b0110: begin // B <<< 1 (left shift)
                    exp_res = (b << 1);
                end
                4'b0111: begin // B >>> 1 arithmetic right shift
                    exp_res = $signed(b) >>> 1;
                end
                4'b1100: begin // A rotate left by 1
                    exp_res = {a[6:0], a[7]};
                end
                4'b1101: begin // A rotate right by 1
                    exp_res = {a[0], a[7:1]};
                end
                4'b1000: begin // not A
                    exp_res = ~a;
                end
                4'b1001: begin // A and B
                    exp_res = a & b;
                end
                4'b1010: begin // A or B
                    exp_res = a | b;
                end
                4'b1011: begin // A nand B
                    exp_res = ~(a & b);
                end
                default: begin
                    exp_res = 8'b00000000;
                end
            endcase

            exp_zero = (exp_res == 8'b00000000);
            exp_neg = exp_res[7];
        end
    endtask

    
    task check_case(input [7:0] a, input [7:0] b, input [3:0] op);
        reg [7:0] exp_res;
        reg exp_zero, exp_neg, exp_ovf;
        begin
            compute_expected(a, b, op, exp_res, exp_zero, exp_neg, exp_ovf);

            A = a; B = b; AluOp = op;
            #1;

            if (Result !== exp_res || Zero !== exp_zero || Negative !== exp_neg || Overflow !== exp_ovf) begin
                $display("FAIL AluOp=%b A=%08b B=%08b | Got R=%08b Z=%b N=%b V=%b | Exp R=%08b Z=%b N=%b V=%b",
                    op, a, b, Result, Zero, Negative, Overflow, exp_res, exp_zero, exp_neg, exp_ovf);
                failures = failures + 1;
            end else begin
                $display("PASS AluOp=%b A=%08b B=%08b | R=%08b Z=%b N=%b V=%b",
                    op, a, b, Result, Zero, Negative, Overflow);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_ALU_8.vcd");
        $dumpvars(0, tb_ALU_8);

        failures = 0;

        $display("=== Deterministic arithmetic tests ===");
        check_case(8'b00000000, 8'b00000000, 4'b0000); // 0 + 0
        check_case(8'b01111111, 8'b00000001, 4'b0000); // overflow positive
        check_case(8'b10000000, 8'b11111111, 4'b0000); // -128 + -1 overflow

        check_case(8'b00000101, 8'b00010000, 4'b0001); // B - A
        check_case(8'b11111111, 8'b00000000, 4'b0010); // -1 + 1 -> 0

        check_case(8'b00010010, 8'b00010010, 4'b0101);
        check_case(8'b00010010, 8'b00010011, 4'b0101);

        check_case(8'b10100101, 8'b00111100, 4'b0110); // B << 1
        check_case(8'b10100101, 8'b11110000, 4'b0111); // B >>> 1
        check_case(8'b10000000, 8'b00000000, 4'b1100); // A rotate left
        check_case(8'b00000001, 8'b00000000, 4'b1101); // A rotate right

        check_case(8'b11111111, 8'b00000000, 4'b1000); // not A
        check_case(8'b11110000, 8'b00001111, 4'b1001); // and
        check_case(8'b11110000, 8'b00001111, 4'b1010); // or
        check_case(8'b11110000, 8'b00001111, 4'b1011); // nand

        $display("=== Sweep AluOp for fixed operands ===");
        for (i = 0; i < 16; i = i + 1) begin
            check_case(8'b00111100, 8'b00010010, i[3:0]);
        end

        $display("=== Randomized tests (100) ===");
        for (i = 0; i < 100; i = i + 1) begin
            check_case($random, $random, $random & 4'hF);
        end

        if (failures == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("TOTAL FAILURES: %0d", failures);
        end

        #1 $finish;
    end
endmodule