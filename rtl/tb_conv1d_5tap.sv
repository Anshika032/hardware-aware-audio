`timescale 1ns/1ps

module tb_conv1d_5tap;

    logic signed [7:0] x0, x1, x2, x3, x4;
    logic signed [7:0] w0, w1, w2, w3, w4;

    logic signed [31:0] result;

    // --------------------------------------------------------
    // Device Under Test
    // --------------------------------------------------------

    conv1d_5tap dut (
        .x0(x0),
        .x1(x1),
        .x2(x2),
        .x3(x3),
        .x4(x4),

        .w0(w0),
        .w1(w1),
        .w2(w2),
        .w3(w3),
        .w4(w4),

        .result(result)
    );

    initial begin

        // ====================================================
        // TEST 1
        // [1,2,3,4,5] . [1,1,1,1,1] = 15
        // ====================================================

        x0 = 1;
        x1 = 2;
        x2 = 3;
        x3 = 4;
        x4 = 5;

        w0 = 1;
        w1 = 1;
        w2 = 1;
        w3 = 1;
        w4 = 1;

        #10;

        $display("TEST 1");
        $display("Expected: 15");
        $display("Actual:   %0d", result);

        if (result == 15)
            $display("PASS");
        else
            $display("FAIL");


        // ====================================================
        // TEST 2
        // [1,2,3,4,5] . [2,2,2,2,2] = 30
        // ====================================================

        w0 = 2;
        w1 = 2;
        w2 = 2;
        w3 = 2;
        w4 = 2;

        #10;

        $display("\nTEST 2");
        $display("Expected: 30");
        $display("Actual:   %0d", result);

        if (result == 30)
            $display("PASS");
        else
            $display("FAIL");


        // ====================================================
        // TEST 3
        // Mixed signed values
        //
        // [10,-5,3,-2,4]
        // [-2,3,4,-5,2]
        //
        // = -20 -15 +12 +10 +8
        // = -5
        // ====================================================

        x0 = 10;
        x1 = -5;
        x2 = 3;
        x3 = -2;
        x4 = 4;

        w0 = -2;
        w1 = 3;
        w2 = 4;
        w3 = -5;
        w4 = 2;

        #10;

        $display("\nTEST 3");
        $display("Expected: -5");
        $display("Actual:   %0d", result);

        if (result == -5)
            $display("PASS");
        else
            $display("FAIL");


        // ====================================================
        // Finish
        // ====================================================

        #10;

        $display("\n======================================");
        $display("5-TAP CONV1D TEST COMPLETE");
        $display("======================================");

        $finish;

    end

endmodule
