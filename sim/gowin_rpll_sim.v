// =============================================================================
// Behavioural simulation model for Gowin rPLL
// Used by iverilog; Yosys uses the real primitive during synthesis.
// Simply passes the clock through and asserts lock after a short delay.
// =============================================================================
/* verilator lint_off UNUSEDSIGNAL */
module rPLL (
    input  wire       CLKIN,
    input  wire       CLKFB,
    input  wire       RESET,
    input  wire       RESET_P,
    input  wire [5:0] FBDSEL,
    input  wire [5:0] IDSEL,
    input  wire [5:0] ODSEL,
    input  wire [3:0] PSDA,
    input  wire [3:0] DUTYDA,
    input  wire [3:0] FDLY,
    output wire       CLKOUT,
    output reg        LOCK,
    output wire       CLKOUTP,
    output wire       CLKOUTD,
    output wire       CLKOUTD3
);

    // All parameters accepted but ignored in simulation
    parameter FCLKIN           = "100";
    parameter DEVICE           = "GW2A-18";
    parameter IDIV_SEL         = 0;
    parameter FBDIV_SEL        = 0;
    parameter ODIV_SEL         = 8;
    parameter DYN_IDIV_SEL     = "false";
    parameter DYN_FBDIV_SEL    = "false";
    parameter DYN_ODIV_SEL     = "false";
    parameter PSDA_SEL         = "0000";
    parameter DYN_DA_EN        = "false";
    parameter DUTYDA_SEL       = "1000";
    parameter CLKOUT_FT_DIR    = 1'b1;
    parameter CLKOUTP_FT_DIR   = 1'b1;
    parameter CLKOUT_DLY_STEP  = 0;
    parameter CLKOUTP_DLY_STEP = 0;
    parameter CLKFB_SEL        = "internal";
    parameter CLKOUT_BYPASS    = "false";
    parameter CLKOUTP_BYPASS   = "false";
    parameter CLKOUTD_BYPASS   = "false";
    parameter DYN_SDIV_SEL     = 2;
    parameter CLKOUTD_SRC      = "CLKOUT";
    parameter CLKOUTD3_SRC     = "CLKOUT";
    parameter CLKOUTP_EN       = "false";
    parameter CLKOUTD_EN       = "false";
    parameter CLKOUTD3_EN      = "false";

    assign CLKOUT  = CLKIN;
    assign CLKOUTP = CLKIN;
    assign CLKOUTD = CLKIN;
    assign CLKOUTD3= CLKIN;

    // Assert lock after a few cycles
    initial begin
        LOCK = 1'b0;
        #100;
        LOCK = 1'b1;
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
