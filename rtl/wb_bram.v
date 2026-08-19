// =============================================================================
// Wishbone BRAM Slave — 32 KB dual-port (8192 × 32-bit words)
// Port A: instruction read (directly from core, word-addressed, synchronous)
// Port B: data read/write via Wishbone (1-cycle ack latency)
// Initialized with $readmemh from firmware.hex.
//
// Word-level writes only to enable Gowin BSRAM inference by Yosys.
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

    // ---- Port B: Wishbone data access ----
    // Single-cycle ack: on the rising edge where stb is seen, we register
    // the read data and assert ack.  The master samples wb_dat_o on the
    // same edge it sees ack=1.
    always @(posedge clk) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
            wb_ack_o <= 1'b1;
            wb_dat_o <= mem[waddr];        // synchronous read
            if (wb_we_i)
                mem[waddr] <= wb_dat_i;    // synchronous write
        end else begin
            wb_ack_o <= 1'b0;
        end
    end

endmodule
