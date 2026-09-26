module conv1d_5tap (

    input  logic signed [7:0] x0,
    input  logic signed [7:0] x1,
    input  logic signed [7:0] x2,
    input  logic signed [7:0] x3,
    input  logic signed [7:0] x4,

    input  logic signed [7:0] w0,
    input  logic signed [7:0] w1,
    input  logic signed [7:0] w2,
    input  logic signed [7:0] w3,
    input  logic signed [7:0] w4,

    output logic signed [31:0] result

);

    logic signed [15:0] p0;
    logic signed [15:0] p1;
    logic signed [15:0] p2;
    logic signed [15:0] p3;
    logic signed [15:0] p4;

    // --------------------------------------------------------
    // INT8 multiplications
    // --------------------------------------------------------

    assign p0 = x0 * w0;
    assign p1 = x1 * w1;
    assign p2 = x2 * w2;
    assign p3 = x3 * w3;
    assign p4 = x4 * w4;

    // --------------------------------------------------------
    // INT32 accumulation
    // --------------------------------------------------------

    always_comb begin

        result = p0
               + p1
               + p2
               + p3
               + p4;

    end

endmodule
