`timescale 1ns/1ps

module tb_conv2_32ch;

    parameter IN_CHANNELS  = 16;
    parameter OUT_CHANNELS = 32;
    parameter KERNEL_SIZE  = 5;
    parameter INPUT_LENGTH = 512;
    parameter OUTPUT_LENGTH = INPUT_LENGTH-KERNEL_SIZE+1;

    logic clk;
    logic rst;
    logic start;

    logic signed [7:0] input_data
        [0:IN_CHANNELS-1][0:INPUT_LENGTH-1];

    logic signed [7:0] weights
        [0:OUT_CHANNELS-1][0:IN_CHANNELS-1][0:KERNEL_SIZE-1];

    logic signed [31:0] bias
        [0:OUT_CHANNELS-1];

    // Output-memory read interface
    logic [$clog2(OUT_CHANNELS)-1:0] read_out_ch;
    logic [$clog2(OUTPUT_LENGTH)-1:0] read_out_pos;

    logic signed [31:0] read_data;

    logic busy;
    logic done;

    integer i, o, k, n;
    integer expected;
    integer errors;
    integer cycles;

    conv2_32ch #(
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_LENGTH(INPUT_LENGTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_data(input_data),
        .weights(weights),
        .bias(bias),
        .read_out_ch(read_out_ch),
        .read_out_pos(read_out_pos),
        .read_data(read_data),
        .busy(busy),
        .done(done)
    );

    // 10 ns clock
    always #5 clk = ~clk;

    initial begin

        clk = 0;
        rst = 1;
        start = 0;

        read_out_ch = 0;
        read_out_pos = 0;

        errors = 0;
        cycles = 0;

        // -------------------------------------------------
        // Deterministic INT8 input data
        // -------------------------------------------------
        for (i = 0; i < IN_CHANNELS; i = i + 1) begin
            for (n = 0; n < INPUT_LENGTH; n = n + 1) begin
                input_data[i][n] = (i + n) % 8 - 4;
            end
        end

        // -------------------------------------------------
        // Deterministic INT8 weights and INT32 bias
        // -------------------------------------------------
        for (o = 0; o < OUT_CHANNELS; o = o + 1) begin

            bias[o] = o - 16;

            for (i = 0; i < IN_CHANNELS; i = i + 1) begin
                for (k = 0; k < KERNEL_SIZE; k = k + 1) begin
                    weights[o][i][k] = (o + i + k) % 5 - 2;
                end
            end
        end

        // -------------------------------------------------
        // Reset
        // -------------------------------------------------
        #20;
        rst = 0;

        // -------------------------------------------------
        // Start convolution
        // -------------------------------------------------
        @(posedge clk);
        start = 1;

        @(posedge clk);
        start = 0;

        // -------------------------------------------------
        // Wait for completion
        // -------------------------------------------------
        while (!done) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        #1;

        $display("");
        $display("==========================================");
        $display("H5 32-Output-Channel Conv2 Test");
        $display("==========================================");
        $display("Simulation cycles: %0d", cycles);

        // -------------------------------------------------
        // Verify every output
        // -------------------------------------------------
        for (o = 0; o < OUT_CHANNELS; o = o + 1) begin

            for (n = 0; n < OUTPUT_LENGTH; n = n + 1) begin

                read_out_ch = o;
                read_out_pos = n;

                #1;

                expected = bias[o];

                for (i = 0; i < IN_CHANNELS; i = i + 1) begin

                    for (k = 0; k < KERNEL_SIZE; k = k + 1) begin

                        expected = expected +
                            input_data[i][n+k] *
                            weights[o][i][k];

                    end
                end

                if (read_data !== expected) begin

                    if (errors < 10) begin
                        $display(
                            "ERROR: out_ch=%0d pos=%0d RTL=%0d EXPECTED=%0d",
                            o, n, read_data, expected
                        );
                    end

                    errors = errors + 1;

                end

            end
        end

        // -------------------------------------------------
        // Final result
        // -------------------------------------------------
        if (errors == 0) begin

            $display("");
            $display(
                "ALL %0d OUTPUTS PASSED",
                OUT_CHANNELS * OUTPUT_LENGTH
            );

            $display("H5 FUNCTIONAL TEST: PASS");

        end
        else begin

            $display("");
            $display("TOTAL ERRORS: %0d", errors);
            $display("H5 FUNCTIONAL TEST: FAIL");

        end

        $finish;

    end

endmodule
