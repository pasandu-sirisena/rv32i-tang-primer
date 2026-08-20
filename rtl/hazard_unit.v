// Hazard detection and pipeline stall unit
module hazard_unit (
    // Inputs from decode and execute stages
    input  wire       id_ex_mem_read,
    input  wire [4:0] id_ex_rd,
    input  wire [4:0] if_id_rs1,
    input  wire [4:0] if_id_rs2,
    input  wire       branch_taken,
    input  wire       jump_taken,
    input  wire       div_busy,
    input  wire       wb_stall,

    // Pipeline control outputs
    output wire       stall_if,
    output wire       stall_id,
    output wire       stall_ex,
    output wire       stall_mem,
    output wire       flush_if_id,
    output wire       flush_id_ex
);

    // Detect load use data hazard when ID stage depends on EX load result
    wire load_use = id_ex_mem_read
                  && (id_ex_rd != 5'd0)
                  && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));

    // Branch or jump resolution flag
    wire take_branch = branch_taken | jump_taken;

    // Pipeline stall generation with priority arbitration
    assign stall_mem = wb_stall;
    assign stall_ex  = stall_mem | div_busy;
    assign stall_id  = stall_ex  | load_use;
    assign stall_if  = stall_id;

    // Pipeline register flush generation
    assign flush_if_id = take_branch & ~stall_ex;
    assign flush_id_ex = (load_use | take_branch) & ~stall_mem;

endmodule
