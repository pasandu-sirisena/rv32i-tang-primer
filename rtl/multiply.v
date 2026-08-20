// Combinational 32-bit hardware multiplier
module multiply (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [1:0]  mul_op,
    output reg  [31:0] result
);

    // Full precision multiplication products
    wire signed [63:0] ss = $signed(a) * $signed(b);
    wire [63:0]        uu = {32'd0, a} * {32'd0, b};

    // Signed by unsigned product for MULHSU
    wire signed [32:0] a_s33 = {a[31], a};
    wire signed [32:0] b_u33 = {1'b0, b};
    wire signed [65:0] su_66 = a_s33 * b_u33;

    // Operation result selection
    always @(*) begin
        case (mul_op)
            2'b00:   result = ss[31:0];
            2'b01:   result = ss[63:32];
            2'b10:   result = su_66[63:32];
            2'b11:   result = uu[63:32];
            default: result = 32'd0;
        endcase
    end

endmodule
