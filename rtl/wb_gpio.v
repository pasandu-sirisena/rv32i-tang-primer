// =============================================================================
// Wishbone GPIO — 4-bit output register for LEDs
// Address 0x20000000: read/write [3:0] LED output (active-low on board)
// =============================================================================
module wb_gpio (
    input  wire        clk,
    input  wire        rst_n,
    // Wishbone slave
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,
    // GPIO output
    output reg  [3:0]  gpio_out
);

    always @(posedge clk) begin
        if (!rst_n) begin
            gpio_out <= 4'b0000;
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else begin
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                wb_dat_o <= {28'd0, gpio_out};
                if (wb_we_i)
                    gpio_out <= wb_dat_i[3:0];
            end else begin
                wb_ack_o <= 1'b0;
            end
        end
    end

endmodule
