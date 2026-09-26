module conv2_32ch #(
    parameter IN_CHANNELS  = 16,
    parameter OUT_CHANNELS = 32,
    parameter KERNEL_SIZE  = 5,
    parameter INPUT_LENGTH = 512
)(
    input  logic clk,
    input logic rst,
    input logic start,

    // INT8 input feature map
    input logic signed [7:0] input_data
        [0:IN_CHANNELS-1][0:INPUT_LENGTH-1],

    // INT8 weights
    input logic signed [7:0] weights
        [0:OUT_CHANNELS-1][0:IN_CHANNELS-1][0:KERNEL_SIZE-1],

    // INT32 bias
    input logic signed [31:0] bias
        [0:OUT_CHANNELS-1],

    // Output-memory read interface
    input logic [$clog2(OUT_CHANNELS)-1:0] read_out_ch,
    input logic [$clog2(INPUT_LENGTH-KERNEL_SIZE+1)-1:0] read_out_pos,

    output logic signed [31:0] read_data,

    output logic busy,
    output logic done
);

    localparam OUTPUT_LENGTH = INPUT_LENGTH-KERNEL_SIZE+1;

    // --------------------------------------------------------
    // Internal output memory
    // --------------------------------------------------------
    logic signed [31:0] output_memory
        [0:OUT_CHANNELS-1][0:OUTPUT_LENGTH-1];

    assign read_data = output_memory[read_out_ch][read_out_pos];

    // --------------------------------------------------------
    // Control
    // --------------------------------------------------------
    integer out_ch;
    integer out_pos;
    integer in_ch;
    integer kernel_pos;

    logic signed [31:0] accumulator;
    logic running;

    assign busy = running;

    // --------------------------------------------------------
    // Sequential MAC engine
    // One INT8 x INT8 MAC per clock
    // --------------------------------------------------------
    always_ff @(posedge clk) begin

        if (rst) begin

            out_ch      <= 0;
            out_pos     <= 0;
            in_ch       <= 0;
            kernel_pos  <= 0;

            accumulator <= 32'sd0;

            running     <= 1'b0;
            done        <= 1'b0;

        end

        else begin

            done <= 1'b0;

            // ------------------------------------------------
            // Start convolution
            // ------------------------------------------------
            if (start && !running) begin

                out_ch      <= 0;
                out_pos     <= 0;
                in_ch       <= 0;
                kernel_pos  <= 0;

                accumulator <= bias[0];

                running     <= 1'b1;

            end

            // ------------------------------------------------
            // One MAC per clock
            // ------------------------------------------------
            else if (running) begin

                accumulator <= accumulator +
                    ($signed(input_data[in_ch][out_pos + kernel_pos]) *
                     $signed(weights[out_ch][in_ch][kernel_pos]));

                // ------------------------------------------------
                // Last kernel tap
                // ------------------------------------------------
                if (kernel_pos == KERNEL_SIZE-1) begin

                    kernel_pos <= 0;

                    // ------------------------------------------------
                    // Last input channel
                    // ------------------------------------------------
                    if (in_ch == IN_CHANNELS-1) begin

                        in_ch <= 0;

                        // Store complete accumulated result
                        output_memory[out_ch][out_pos] <=
                            accumulator +
                            ($signed(input_data[in_ch][out_pos + kernel_pos]) *
                             $signed(weights[out_ch][in_ch][kernel_pos]));

                        // ------------------------------------------------
                        // Last output position
                        // ------------------------------------------------
                        if (out_pos == OUTPUT_LENGTH-1) begin

                            out_pos <= 0;

                            // ------------------------------------------------
                            // Last output channel
                            // ------------------------------------------------
                            if (out_ch == OUT_CHANNELS-1) begin

                                running <= 1'b0;
                                done    <= 1'b1;

                            end

                            else begin

                                out_ch <= out_ch + 1;

                                // New output channel starts with its bias
                                accumulator <= bias[out_ch + 1];

                            end

                        end

                        else begin

                            out_pos <= out_pos + 1;

                            // Every output position starts with channel bias
                            accumulator <= bias[out_ch];

                        end

                    end

                    else begin

                        in_ch <= in_ch + 1;

                    end

                end

                else begin

                    kernel_pos <= kernel_pos + 1;

                end
            end
        end
    end

endmodule
