// Wishbone interconnect and address decoder for system peripherals
module wb_interconnect (
    // Wishbone master interface from CPU
    input  wire        m_cyc_i,
    input  wire        m_stb_i,
    input  wire        m_we_i,
    input  wire [31:0] m_adr_i,
    input  wire [31:0] m_dat_i,
    input  wire [3:0]  m_sel_i,
    output wire [31:0] m_dat_o,
    output wire        m_ack_o,

    // Slave 0 interface for BRAM memory
    output wire        s0_cyc_o,
    output wire        s0_stb_o,
    output wire        s0_we_o,
    output wire [31:0] s0_adr_o,
    output wire [31:0] s0_dat_o,
    output wire [3:0]  s0_sel_o,
    input  wire [31:0] s0_dat_i,
    input  wire        s0_ack_i,

    // Slave 1 interface for UART controller
    output wire        s1_cyc_o,
    output wire        s1_stb_o,
    output wire        s1_we_o,
    output wire [31:0] s1_adr_o,
    output wire [31:0] s1_dat_o,
    output wire [3:0]  s1_sel_o,
    input  wire [31:0] s1_dat_i,
    input  wire        s1_ack_i,

    // Slave 2 interface for GPIO LEDs
    output wire        s2_cyc_o,
    output wire        s2_stb_o,
    output wire        s2_we_o,
    output wire [31:0] s2_adr_o,
    output wire [31:0] s2_dat_o,
    output wire [3:0]  s2_sel_o,
    input  wire [31:0] s2_dat_i,
    input  wire        s2_ack_i
);

    // Address decoding logic
    wire sel0 = (m_adr_i[31:28] == 4'h0);
    wire sel1 = (m_adr_i[31:28] == 4'h1);
    wire sel2 = (m_adr_i[31:28] == 4'h2);

    // Forward bus request signals to BRAM
    assign s0_cyc_o = m_cyc_i & sel0;
    assign s0_stb_o = m_stb_i & sel0;
    assign s0_we_o  = m_we_i;
    assign s0_adr_o = m_adr_i;
    assign s0_dat_o = m_dat_i;
    assign s0_sel_o = m_sel_i;

    // Forward bus request signals to UART
    assign s1_cyc_o = m_cyc_i & sel1;
    assign s1_stb_o = m_stb_i & sel1;
    assign s1_we_o  = m_we_i;
    assign s1_adr_o = m_adr_i;
    assign s1_dat_o = m_dat_i;
    assign s1_sel_o = m_sel_i;

    // Forward bus request signals to GPIO
    assign s2_cyc_o = m_cyc_i & sel2;
    assign s2_stb_o = m_stb_i & sel2;
    assign s2_we_o  = m_we_i;
    assign s2_adr_o = m_adr_i;
    assign s2_dat_o = m_dat_i;
    assign s2_sel_o = m_sel_i;

    // Multiplex read data from active slave back to master
    assign m_dat_o = sel0 ? s0_dat_i :
                     sel1 ? s1_dat_i :
                     sel2 ? s2_dat_i : 32'd0;

    // Route acknowledge signal back to master
    assign m_ack_o = (sel0 & s0_ack_i)
                   | (sel1 & s1_ack_i)
                   | (sel2 & s2_ack_i);

endmodule
