// =============================================================================
// Wishbone B4 Address Decoder / Interconnect
// Routes a single master to one of three slaves based on address bits [31:28].
//   0x0_______ → BRAM  (slave 0)
//   0x1_______ → UART  (slave 1)
//   0x2_______ → GPIO  (slave 2)
// =============================================================================
module wb_interconnect (
    // Master port
    input  wire        m_cyc_i,
    input  wire        m_stb_i,
    input  wire        m_we_i,
    input  wire [31:0] m_adr_i,
    input  wire [31:0] m_dat_i,
    input  wire [3:0]  m_sel_i,
    output wire [31:0] m_dat_o,
    output wire        m_ack_o,
    // Slave 0 — BRAM
    output wire        s0_cyc_o,
    output wire        s0_stb_o,
    output wire        s0_we_o,
    output wire [31:0] s0_adr_o,
    output wire [31:0] s0_dat_o,
    output wire [3:0]  s0_sel_o,
    input  wire [31:0] s0_dat_i,
    input  wire        s0_ack_i,
    // Slave 1 — UART
    output wire        s1_cyc_o,
    output wire        s1_stb_o,
    output wire        s1_we_o,
    output wire [31:0] s1_adr_o,
    output wire [31:0] s1_dat_o,
    output wire [3:0]  s1_sel_o,
    input  wire [31:0] s1_dat_i,
    input  wire        s1_ack_i,
    // Slave 2 — GPIO
    output wire        s2_cyc_o,
    output wire        s2_stb_o,
    output wire        s2_we_o,
    output wire [31:0] s2_adr_o,
    output wire [31:0] s2_dat_o,
    output wire [3:0]  s2_sel_o,
    input  wire [31:0] s2_dat_i,
    input  wire        s2_ack_i
);

    // Decode based on address bits [31:28]
    wire sel0 = (m_adr_i[31:28] == 4'h0);  // BRAM
    wire sel1 = (m_adr_i[31:28] == 4'h1);  // UART
    wire sel2 = (m_adr_i[31:28] == 4'h2);  // GPIO

    // Common bus signals forwarded to all slaves; only strobe is gated
    assign s0_cyc_o = m_cyc_i & sel0;
    assign s0_stb_o = m_stb_i & sel0;
    assign s0_we_o  = m_we_i;
    assign s0_adr_o = m_adr_i;
    assign s0_dat_o = m_dat_i;
    assign s0_sel_o = m_sel_i;

    assign s1_cyc_o = m_cyc_i & sel1;
    assign s1_stb_o = m_stb_i & sel1;
    assign s1_we_o  = m_we_i;
    assign s1_adr_o = m_adr_i;
    assign s1_dat_o = m_dat_i;
    assign s1_sel_o = m_sel_i;

    assign s2_cyc_o = m_cyc_i & sel2;
    assign s2_stb_o = m_stb_i & sel2;
    assign s2_we_o  = m_we_i;
    assign s2_adr_o = m_adr_i;
    assign s2_dat_o = m_dat_i;
    assign s2_sel_o = m_sel_i;

    // Return path: mux slave responses
    assign m_dat_o = sel0 ? s0_dat_i :
                     sel1 ? s1_dat_i :
                     sel2 ? s2_dat_i : 32'd0;

    assign m_ack_o = (sel0 & s0_ack_i)
                   | (sel1 & s1_ack_i)
                   | (sel2 & s2_ack_i);

endmodule
