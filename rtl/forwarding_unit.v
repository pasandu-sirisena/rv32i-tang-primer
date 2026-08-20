// Operand forwarding multiplexer control unit
module forwarding_unit (
    // Execute stage source registers
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,

    // Memory stage writeback state
    input  wire [4:0] mem_rd,
    input  wire       mem_reg_write,
    input  wire       mem_is_load,

    // Writeback stage register state
    input  wire [4:0] wb_rd,
    input  wire       wb_reg_write,

    // Forwarding selector outputs
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    // Forwarding priority and hazard check
    always @(*) begin
        // Source register 1 forwarding
        if (mem_reg_write && !mem_is_load && (mem_rd != 5'd0) && (mem_rd == ex_rs1))
            forward_a = 2'b10;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // Source register 2 forwarding
        if (mem_reg_write && !mem_is_load && (mem_rd != 5'd0) && (mem_rd == ex_rs2))
            forward_b = 2'b10;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

endmodule
