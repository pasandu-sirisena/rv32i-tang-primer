// Wishbone slave peripheral for output GPIO
module wb_gpio (
    // Clock and reset inputs
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone bus interface
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,

    // Output pin register
    output reg  [5:0]  gpio_out
);

    // Wishbone read and write handling
    always @(posedge clk) begin
        if (!rst_n) begin
            gpio_out <= 6'b000000;
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else begin
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                wb_dat_o <= {26'd0, gpio_out};
                if (wb_we_i)
                    gpio_out <= wb_dat_i[5:0];
            end else begin
                wb_ack_o <= 1'b0;
            end
        end
    end

endmodule
