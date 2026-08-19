// =============================================================================
// RV32IM Register File
// 32 x 32-bit registers, 2 read ports, 1 write port
// x0 is hardwired to zero. Write-through for simultaneous read/write.
// =============================================================================
module regfile (
    input  wire        clk,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  wr_addr,
    input  wire [31:0] wr_data,
    input  wire        wr_en,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

    reg [31:0] regs [1:31];

    integer i;
    initial begin
        for (i = 1; i < 32; i = i + 1)
            regs[i] = 32'd0;
    end

    // Synchronous write
    always @(posedge clk) begin
        if (wr_en && (wr_addr != 5'd0))
            regs[wr_addr] <= wr_data;
    end

    // Combinational read with write-through (handles WB→ID forwarding)
    assign rs1_data = (rs1_addr == 5'd0)                       ? 32'd0   :
                      (wr_en && wr_addr == rs1_addr)            ? wr_data :
                                                                  regs[rs1_addr];

    assign rs2_data = (rs2_addr == 5'd0)                       ? 32'd0   :
                      (wr_en && wr_addr == rs2_addr)            ? wr_data :
                                                                  regs[rs2_addr];
endmodule
