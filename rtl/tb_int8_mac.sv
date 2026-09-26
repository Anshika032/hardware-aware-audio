`timescale 1ns/1ps

module tb_int8_mac;

    logic clk;
    logic rst;
    logic valid_in;

    logic signed [7:0] data_in;
    logic signed [7:0] weight_in;
    logic signed [31:0] acc_in;

    logic valid_out;
    logic signed [31:0] acc_out;

    // --------------------------------------------------------
    // Device Under Test
    // --------------------------------------------------------

    int8_mac dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .data_in(data_in),
        .weight_in(weight_in),
        .acc_in(acc_in),
        .valid_out(valid_out),
        .acc_out(acc_out)
    );

    // --------------------------------------------------------
    // Clock: 10 ns period
    // --------------------------------------------------------

    always #5 clk = ~clk;

    // --------------------------------------------------------
    // Test sequence
    // --------------------------------------------------------

    initial begin

        clk = 0;
        rst = 1;
        valid_in = 0;

        data_in = 0;
        weight_in = 0;
        acc_in = 0;

        // Reset
        #20;
        rst = 0;

        // ====================================================
        // TEST 1
        // 10 x 3 + 100 = 130
        // ====================================================

        @(negedge clk);

        data_in = 10;
        weight_in = 3;
        acc_in = 100;
        valid_in = 1;

        @(negedge clk);
        valid_in = 0;

        @(posedge clk);
        #1;

        $display("TEST 1");
        $display("Expected: 130");
        $display("Actual:   %0d", acc_out);

        if (acc_out == 130)
            $display("PASS");
        else
            $display("FAIL");


        // ====================================================
        // TEST 2
        // -10 x 3 + 100 = 70
        // ====================================================

        @(negedge clk);

        data_in = -10;
        weight_in = 3;
        acc_in = 100;
        valid_in = 1;

        @(negedge clk);
        valid_in = 0;

        @(posedge clk);
        #1;

        $display("\nTEST 2");
        $display("Expected: 70");
        $display("Actual:   %0d", acc_out);

        if (acc_out == 70)
            $display("PASS");
        else
            $display("FAIL");


        // ====================================================
        // TEST 3
        // -20 x -4 + (-50) = 30
        // ====================================================

        @(negedge clk);

        data_in = -20;
        weight_in = -4;
        acc_in = -50;
        valid_in = 1;

        @(negedge clk);
        valid_in = 0;

        @(posedge clk);
        #1;

        $display("\nTEST 3");
        $display("Expected: 30");
        $display("Actual:   %0d", acc_out);

        if (acc_out == 30)
            $display("PASS");
        else
            $display("FAIL");


        // ====================================================
        // Finish
        // ====================================================

        #20;

        $display("\n======================================");
        $display("INT8 MAC TEST COMPLETE");
        $display("======================================");

        $finish;

    end

endmodule
