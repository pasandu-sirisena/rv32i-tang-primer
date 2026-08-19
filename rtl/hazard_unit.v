// =============================================================================
// Hazard Detection Unit
// Detects load-use hazards and generates stall / flush signals.
// =============================================================================
module hazard_unit (
    // Load-use detection inputs (instruction in EX, instruction in ID)
    input  wire       id_ex_mem_read,   // EX stage has a load
    input  wire [4:0] id_ex_rd,         // EX stage destination register
    input  wire [4:0] if_id_rs1,        // ID stage source register 1
    input  wire [4:0] if_id_rs2,        // ID stage source register 2
    // Branch / jump (resolved in EX)
    input  wire       branch_taken,
    input  wire       jump_taken,
    // Divider
    input  wire       div_busy,
    // Wishbone stall (MEM stage waiting for ack)
    input  wire       wb_stall,
    // Outputs
    output wire       stall_if,
    output wire       stall_id,
    output wire       stall_ex,
    output wire       stall_mem,
    output wire       flush_if_id,
    output wire       flush_id_ex
);

    // Load-use hazard: load in EX, dependent instruction in ID
    wire load_use = id_ex_mem_read
                  && (id_ex_rd != 5'd0)
                  && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));

    wire take_branch = branch_taken | jump_taken;

    // ---------- Stall signals (active high) ----------
    // Priority: wb_stall > div_busy > load_use
    assign stall_mem = wb_stall;
    assign stall_ex  = stall_mem | div_busy;
    assign stall_id  = stall_ex  | load_use;
    assign stall_if  = stall_id;

    // ---------- Flush signals ----------
    // Flush IF/ID and ID/EX on taken branch/jump (but NOT during a stall)
    assign flush_if_id = take_branch & ~stall_ex;
    assign flush_id_ex = (load_use | take_branch) & ~stall_mem;

endmodule
