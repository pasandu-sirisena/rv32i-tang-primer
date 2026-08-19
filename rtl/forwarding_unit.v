// =============================================================================
// Data Forwarding Unit
// Generates mux selects to forward results from MEM/WB stages to EX inputs.
//   forward = 2'b00 → use register file output (no forwarding)
//   forward = 2'b01 → forward from WB stage
//   forward = 2'b10 → forward from MEM stage (highest priority)
// =============================================================================
module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    // MEM stage
    input  wire [4:0] mem_rd,
    input  wire       mem_reg_write,
    input  wire       mem_is_load,      // suppress MEM forward for loads
    // WB stage
    input  wire [4:0] wb_rd,
    input  wire       wb_reg_write,
    // Outputs
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    always @(*) begin
        // ---------- Forward A (rs1 operand) ----------
        if (mem_reg_write && !mem_is_load && (mem_rd != 5'd0) && (mem_rd == ex_rs1))
            forward_a = 2'b10;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // ---------- Forward B (rs2 operand) ----------
        if (mem_reg_write && !mem_is_load && (mem_rd != 5'd0) && (mem_rd == ex_rs2))
            forward_b = 2'b10;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

endmodule
