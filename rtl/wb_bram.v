// =============================================================================
// Wishbone BRAM Slave — 32 KB dual-port (8192 × 32-bit words)
// Port A: instruction read (directly from core, word-addressed, synchronous)
// Port B: data read/write via Wishbone (1-cycle ack latency)
// Initialized with $readmemh from firmware.hex.
//
// Word-level writes only to enable Gowin BSRAM inference by Yosys.
// Byte/halfword masking is handled by the CPU pipeline.
// =============================================================================
module wb_bram (
    input  wire        clk,
    input  wire        rst_n,
    // ---- Port A: instruction read ----
    input  wire [12:0] iaddr,       // word address (PC[14:2])
    output reg  [31:0] irdata,      // instruction data (registered output)
    // ---- Port B: Wishbone slave ----
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o
);

    // 8192 × 32 = 32 KB
    reg [31:0] mem [0:8191];

    initial $readmemh("rtl/firmware.hex", mem);

    wire [12:0] waddr = wb_adr_i[14:2];   // word address for data port

    // ---- Port A: synchronous read (instruction fetch) ----
    always @(posedge clk)
        irdata <= mem[iaddr];

    // ---- Port B: synchronous read / write (data access) ----
    // Word-level write for BSRAM inference.  The core's MEM stage
    // performs a read-modify-write when executing SB/SH, so the
    // BRAM only ever sees full-word SW operations in practice.
    reg [31:0] portb_rdata;
    always @(posedge clk) begin
        portb_rdata <= mem[waddr];
        if (wb_cyc_i && wb_stb_i && wb_we_i)
            mem[waddr] <= wb_dat_i;
    end

    // ---- Wishbone handshake (1-cycle ack) ----
    always @(posedge clk) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else begin
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                wb_dat_o <= portb_rdata;
            end else begin
                wb_ack_o <= 1'b0;
            end
        end
    end

endmodule
