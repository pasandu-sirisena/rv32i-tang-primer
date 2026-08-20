// Top level module for Tang Primer 20K SoC
module top (
    input  wire       clk_27mhz,
    output wire       uart_tx,
    input  wire       uart_rx,
    output wire [5:0] led_n
);

    // Primary system clock
    wire sys_clk = clk_27mhz;

    // Power on reset generation
    reg [7:0] rst_cnt = 8'd0;
    wire rst_n = (rst_cnt == 8'hFF);

    always @(posedge sys_clk) begin
        if (rst_cnt != 8'hFF)
            rst_cnt <= rst_cnt + 8'd1;
    end

    // Instruction bus signals between CPU and BRAM
    wire [12:0] instr_addr;
    wire        instr_ce;
    wire [31:0] instr_rdata;

    // Wishbone master signals from CPU
    wire        m_cyc, m_stb, m_we;
    wire [31:0] m_adr, m_wdat;
    wire [3:0]  m_sel;
    wire [31:0] m_rdat;
    wire        m_ack;

    // Pipelined RV32IM processor core instance
    rv32im_core u_cpu (
        .clk         (sys_clk),
        .rst_n       (rst_n),
        .instr_addr  (instr_addr),
        .instr_ce    (instr_ce),
        .instr_rdata (instr_rdata),
        .wb_cyc_o    (m_cyc),
        .wb_stb_o    (m_stb),
        .wb_we_o     (m_we),
        .wb_adr_o    (m_adr),
        .wb_dat_o    (m_wdat),
        .wb_sel_o    (m_sel),
        .wb_dat_i    (m_rdat),
        .wb_ack_i    (m_ack)
    );

    // Wishbone slave bus signals
    wire        s0_cyc, s0_stb, s0_we;
    wire [31:0] s0_adr, s0_wdat;
    wire [3:0]  s0_sel;
    wire [31:0] s0_rdat;
    wire        s0_ack;

    wire        s1_cyc, s1_stb, s1_we;
    wire [31:0] s1_adr, s1_wdat;
    wire [3:0]  s1_sel;
    wire [31:0] s1_rdat;
    wire        s1_ack;

    wire        s2_cyc, s2_stb, s2_we;
    wire [31:0] s2_adr, s2_wdat;
    wire [3:0]  s2_sel;
    wire [31:0] s2_rdat;
    wire        s2_ack;

    // Wishbone bus interconnect and routing
    wb_interconnect u_bus (
        .m_cyc_i  (m_cyc),  .m_stb_i  (m_stb),   .m_we_i  (m_we),
        .m_adr_i  (m_adr),  .m_dat_i  (m_wdat),   .m_sel_i (m_sel),
        .m_dat_o  (m_rdat), .m_ack_o  (m_ack),
        .s0_cyc_o (s0_cyc), .s0_stb_o (s0_stb),   .s0_we_o (s0_we),
        .s0_adr_o (s0_adr), .s0_dat_o (s0_wdat),   .s0_sel_o(s0_sel),
        .s0_dat_i (s0_rdat),.s0_ack_i (s0_ack),
        .s1_cyc_o (s1_cyc), .s1_stb_o (s1_stb),   .s1_we_o (s1_we),
        .s1_adr_o (s1_adr), .s1_dat_o (s1_wdat),   .s1_sel_o(s1_sel),
        .s1_dat_i (s1_rdat),.s1_ack_i (s1_ack),
        .s2_cyc_o (s2_cyc), .s2_stb_o (s2_stb),   .s2_we_o (s2_we),
        .s2_adr_o (s2_adr), .s2_dat_o (s2_wdat),   .s2_sel_o(s2_sel),
        .s2_dat_i (s2_rdat),.s2_ack_i (s2_ack)
    );

    // Dual-port block RAM memory instance
    wb_bram u_bram (
        .clk      (sys_clk),
        .rst_n    (rst_n),
        .iaddr    (instr_addr),
        .ice      (instr_ce),
        .irdata   (instr_rdata),
        .wb_cyc_i (s0_cyc),
        .wb_stb_i (s0_stb),
        .wb_we_i  (s0_we),
        .wb_adr_i (s0_adr),
        .wb_dat_i (s0_wdat),
        .wb_sel_i (s0_sel),
        .wb_dat_o (s0_rdat),
        .wb_ack_o (s0_ack)
    );

    // UART peripheral instance
    wb_uart #(
        .CLK_FREQ  (27_000_000),
        .BAUD_RATE (115_200)
    ) u_uart (
        .clk      (sys_clk),
        .rst_n    (rst_n),
        .wb_cyc_i (s1_cyc),
        .wb_stb_i (s1_stb),
        .wb_we_i  (s1_we),
        .wb_adr_i (s1_adr),
        .wb_dat_i (s1_wdat),
        .wb_sel_i (s1_sel),
        .wb_dat_o (s1_rdat),
        .wb_ack_o (s1_ack),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx)
    );

    // GPIO LED peripheral instance
    wire [5:0] gpio_out;

    wb_gpio u_gpio (
        .clk      (sys_clk),
        .rst_n    (rst_n),
        .wb_cyc_i (s2_cyc),
        .wb_stb_i (s2_stb),
        .wb_we_i  (s2_we),
        .wb_adr_i (s2_adr),
        .wb_dat_i (s2_wdat),
        .wb_sel_i (s2_sel),
        .wb_dat_o (s2_rdat),
        .wb_ack_o (s2_ack),
        .gpio_out (gpio_out)
    );

    // Active-low LED polarity inversion for Dock board
    assign led_n = ~gpio_out;

endmodule
