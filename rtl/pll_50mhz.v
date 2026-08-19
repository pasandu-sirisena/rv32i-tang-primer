// =============================================================================
// Gowin rPLL wrapper — 27 MHz → 54 MHz
// Parameters computed for GW2A-18:
//   CLKOUT = 27 × (FBDIV_SEL+1) / (IDIV_SEL+1) = 27×2/1 = 54 MHz
//   VCO    = CLKOUT × ODIV_SEL = 54×16 = 864 MHz  (500-1250 OK)
// =============================================================================
module pll_50mhz (
    input  wire clk_in,      // 27 MHz oscillator
    output wire clk_out,     // 54 MHz system clock
    output wire lock         // PLL lock indicator
);

    rPLL #(
        .FCLKIN           ("27"),
        .DEVICE           ("GW2A-18"),
        .IDIV_SEL         (0),       // IDIV = 1
        .FBDIV_SEL        (1),       // FBDIV = 2  →  CLKOUT = 54 MHz
        .ODIV_SEL         (16),      // ODIV  = 16 →  VCO = 864 MHz
        .DYN_IDIV_SEL     ("false"),
        .DYN_FBDIV_SEL    ("false"),
        .DYN_ODIV_SEL     ("false"),
        .PSDA_SEL         ("0000"),
        .DYN_DA_EN        ("false"),
        .DUTYDA_SEL       ("1000"),
        .CLKOUT_FT_DIR    (1'b1),
        .CLKOUTP_FT_DIR   (1'b1),
        .CLKOUT_DLY_STEP  (0),
        .CLKOUTP_DLY_STEP (0),
        .CLKFB_SEL        ("internal"),
        .CLKOUT_BYPASS     ("false"),
        .CLKOUTP_BYPASS    ("false"),
        .CLKOUTD_BYPASS    ("false"),
        .DYN_SDIV_SEL     (2),
        .CLKOUTD_SRC      ("CLKOUT"),
        .CLKOUTD3_SRC     ("CLKOUT")
    ) u_rpll (
        .CLKIN   (clk_in),
        .CLKOUT  (clk_out),
        .LOCK    (lock),
        .CLKOUTP (),
        .CLKOUTD (),
        .CLKOUTD3(),
        .RESET   (1'b0),
        .RESET_P (1'b0),
        .CLKFB   (1'b0),
        .FBDSEL  (6'b0),
        .IDSEL   (6'b0),
        .ODSEL   (6'b0),
        .PSDA    (4'b0),
        .DUTYDA  (4'b0),
        .FDLY    (4'b0)
    );

endmodule
