module conv1d_16ch (

    input  logic signed [7:0] x [0:15][0:4],
    input  logic signed [7:0] w [0:15][0:4],

    output logic signed [31:0] result

);

    integer ch;
    integer k;

    logic signed [31:0] accumulator;

    always_comb begin

        accumulator = 32'sd0;

        for (ch = 0; ch < 16; ch = ch + 1) begin

            for (k = 0; k < 5; k = k + 1) begin

                accumulator =
                    accumulator + (x[ch][k] * w[ch][k]);

            end

        end

        result = accumulator;

    end

endmodule
