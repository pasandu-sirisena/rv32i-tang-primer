// =============================================================================
// RV32IM Multiplier — Combinational 32×32 → 64-bit
// Implements MUL, MULH, MULHSU, MULHU via Verilog * operator.
// Yosys will infer DSP blocks on Gowin GW2A if available.
// =============================================================================
module multiply (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [1:0]  mul_op,   // 00=MUL 01=MULH 10=MULHSU 11=MULHU
    output reg  [31:0] result
);

    // Signed × signed
    wire signed [63:0] ss = $signed(a) * $signed(b);

    // Unsigned × unsigned
    wire [63:0] uu = {32'd0, a} * {32'd0, b};

    // Signed × unsigned  (MULHSU)
    // Extend a to 33-bit signed, b to 33-bit "signed" with MSB=0
    wire signed [32:0] a_s33  = {a[31], a};
    wire signed [32:0] b_u33  = {1'b0, b};
    wire signed [65:0] su_66  = a_s33 * b_u33;

    always @(*) begin
        case (mul_op)
            2'b00:   result = ss[31:0];       // MUL   — low  32 bits
            2'b01:   result = ss[63:32];      // MULH  — high 32 bits (s×s)
            2'b10:   result = su_66[63:32];   // MULHSU— high 32 bits (s×u)
            2'b11:   result = uu[63:32];      // MULHU — high 32 bits (u×u)
            default: result = 32'd0;
        endcase
    end

endmodule
