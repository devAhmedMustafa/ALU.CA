`timescale 1ns/1ps

module tb_8bit_manipulator;
    reg [7:0] A;
    reg direction; // 0 left, 1 right
    reg rotate;
    wire [7:0] Out;

    // instantiate DUT
    bit8_manipulator DUT (
        .A(A),
        .direction(direction),
        .rotate(rotate),
        .Out(Out)
    );

    integer i;
    integer failures;

    task check_case(input [7:0] in, input dir, input rot);
        reg [7:0] expected;
        begin
            A = in;
            direction = dir;
            rotate = rot;
            #1; // wait for combinational logic

            // compute behavioral expected (intended semantics):
            if (rot == 0) begin
                // logical shifts
                if (dir == 0) begin
                    // left logical shift
                    expected = in << 1;
                end else begin
                    // right logical shift
                    expected = in >> 1;
                end
            end else begin
                // rotates
                if (dir == 0) begin
                    // left rotate: MSB wraps to LSB
                    expected = {in[6:0], in[7]};
                end else begin
                    // right rotate: LSB wraps to MSB
                    expected = {in[0], in[7:1]};
                end
            end

            if (Out !== expected) begin
                $display("FAIL: A=%b dir=%b rot=%b -> Out=%b expected=%b", in, dir, rot, Out, expected);
                failures = failures + 1;
            end else begin
                $display("PASS: A=%b dir=%b rot=%b -> Out=%b", in, dir, rot, Out);
            end
        end
    endtask

    initial begin
        $dumpvars(0, tb_8bit_manipulator);

        failures = 0;

        // deterministic tests
        $display("Running deterministic tests...");
        check_case(8'b00000000, 0, 0); // zero shift left
        check_case(8'b00000000, 1, 0); // zero shift right
        check_case(8'b11111111, 0, 0); // all ones shift left
        check_case(8'b11111111, 1, 0); // all ones shift right
        check_case(8'b10101010, 0, 0); // pattern left
        check_case(8'b10101010, 1, 0); // pattern right

        // rotate tests
        $display("Running rotate tests...");
        check_case(8'b00000001, 0, 1); // rotate left
        check_case(8'b00000001, 1, 1); // rotate right
        check_case(8'b10000000, 0, 1); // rotate left with MSB
        check_case(8'b10000000, 1, 1); // rotate right with MSB
        check_case(8'b10110011, 0, 1);
        check_case(8'b10110011, 1, 1);

        // randomized tests
        $display("Running randomized tests...");
        for (i = 0; i < 20; i = i + 1) begin
            check_case($random, i[0], i[1]);
        end

        if (failures == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("TOTAL FAILURES: %0d", failures);
        end

        #1 $finish;
    end

endmodule
