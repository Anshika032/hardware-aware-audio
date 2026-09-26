`timescale 1ns/1ps

module tb_conv1d_16ch;

    logic signed [7:0] x [0:15][0:4];
    logic signed [7:0] w [0:15][0:4];

    logic signed [31:0] result;

    integer ch;
    integer k;
    integer expected;

    conv1d_16ch dut (
        .x(x),
        .w(w),
        .result(result)
    );

    initial begin

        // =========================================================
        // TEST 1
        // All inputs = 1, all weights = 1
        // Expected = 16 channels x 5 taps x 1 x 1 = 80
        // =========================================================

        for (ch = 0; ch < 16; ch = ch + 1)
            for (k = 0; k < 5; k = k + 1) begin
                x[ch][k] = 1;
                w[ch][k] = 1;
            end

        #10;

        $display("TEST 1: expected = 80, actual = %0d", result);

        if (result == 80)
            $display("TEST 1: PASS");
        else
            $display("TEST 1: FAIL");


        // =========================================================
        // TEST 2
        // All inputs = 2, all weights = 3
        // Expected = 16 x 5 x 2 x 3 = 480
        // =========================================================

        for (ch = 0; ch < 16; ch = ch + 1)
            for (k = 0; k < 5; k = k + 1) begin
                x[ch][k] = 2;
                w[ch][k] = 3;
            end

        #10;

        $display("TEST 2: expected = 480, actual = %0d", result);

        if (result == 480)
            $display("TEST 2: PASS");
        else
            $display("TEST 2: FAIL");


        // =========================================================
        // TEST 3
        // Mixed signed values
        // Calculate expected value independently
        // =========================================================

        for (ch = 0; ch < 16; ch = ch + 1)
            for (k = 0; k < 5; k = k + 1) begin
                x[ch][k] = (ch + k) - 10;
                w[ch][k] = k + 1;
            end

        #10;

        expected = 0;

        for (ch = 0; ch < 16; ch = ch + 1)
            for (k = 0; k < 5; k = k + 1)
                expected = expected + (x[ch][k] * w[ch][k]);

        $display("TEST 3: expected = %0d, actual = %0d",
                 expected, result);

        if (result == expected)
            $display("TEST 3: PASS");
        else
            $display("TEST 3: FAIL");


        // =========================================================
        // COMPLETE
        // =========================================================

        #10;

        $display("----------------------------------------");
        $display("H4 16-channel Conv1D verification complete");
        $display("----------------------------------------");

        $finish;

    end

endmodule
