// =============================================================================
// RV32I ALU — Arithmetic / Logic Unit
// Supports all base integer ALU operations.
// =============================================================================
module alu (
    input  wire [3:0]  alu_op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] result
);

    localparam ALU_ADD   = 4'd0;
    localparam ALU_SUB   = 4'd1;
    localparam ALU_SLL   = 4'd2;
    localparam ALU_SLT   = 4'd3;
    localparam ALU_SLTU  = 4'd4;
    localparam ALU_XOR   = 4'd5;
    localparam ALU_SRL   = 4'd6;
    localparam ALU_SRA   = 4'd7;
    localparam ALU_OR    = 4'd8;
    localparam ALU_AND   = 4'd9;
    localparam ALU_PASSB = 4'd10;  // Pass operand B (used by LUI)

    always @(*) begin
        case (alu_op)
            ALU_ADD:   result = a + b;
            ALU_SUB:   result = a - b;
            ALU_SLL:   result = a << b[4:0];
            ALU_SLT:   result = {31'd0, $signed(a) < $signed(b)};
            ALU_SLTU:  result = {31'd0, a < b};
            ALU_XOR:   result = a ^ b;
            ALU_SRL:   result = a >> b[4:0];
            ALU_SRA:   result = $signed(a) >>> b[4:0];
            ALU_OR:    result = a | b;
            ALU_AND:   result = a & b;
            ALU_PASSB: result = b;
            default:   result = 32'd0;
        endcase
    end

endmodule
