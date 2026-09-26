module int8_mac (
    input  logic               clk,
    input  logic               rst,

    input  logic               valid_in,

    input  logic signed [7:0]  data_in,
    input  logic signed [7:0]  weight_in,

    input  logic signed [31:0]  acc_in,

    output logic               valid_out,
    output logic signed [31:0]  acc_out
);

    logic signed [15:0] product;

    assign product = data_in * weight_in;

    always_ff @(posedge clk) begin

        if (rst) begin
            acc_out   <= 32'sd0;
            valid_out <= 1'b0;
        end
        else begin
            valid_out <= valid_in;

            if (valid_in) begin
                acc_out <= acc_in + product;
            end
        end
    end

endmodule
