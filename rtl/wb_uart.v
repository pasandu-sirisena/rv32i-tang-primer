// =============================================================================
// Wishbone UART — TX and RX, 115 200 baud @ 54 MHz clock
//
// Register map (active on address bits [3:2]):
//   offset 0x00 — TXDATA   (W)   [7:0] byte to transmit
//   offset 0x04 — TXSTATUS (R)   [0]   1 = TX busy
//   offset 0x08 — RXDATA   (R)   [7:0] received byte
//   offset 0x0C — RXSTATUS (R)   [0]   1 = RX data available (cleared on read of RXDATA)
// =============================================================================
module wb_uart #(
    parameter CLK_FREQ  = 54_000_000,
    parameter BAUD_RATE = 115_200
)(
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
    // Physical pins
    output reg         uart_tx,
    input  wire        uart_rx
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;         // ≈ 469
    localparam HALF_DIV = BAUD_DIV / 2;

    // =====================================================================
    //  TX
    // =====================================================================
    reg [9:0]  tx_shift;     // {stop, data[7:0], start}
    reg [3:0]  tx_bit_cnt;   // 0..9
    reg [15:0] tx_clk_cnt;
    reg        tx_busy;

    always @(posedge clk) begin
        if (!rst_n) begin
            uart_tx    <= 1'b1;   // idle high
            tx_busy    <= 1'b0;
            tx_bit_cnt <= 4'd0;
            tx_clk_cnt <= 16'd0;
            tx_shift   <= 10'h3FF;
        end else if (tx_busy) begin
            if (tx_clk_cnt == BAUD_DIV[15:0] - 16'd1) begin
                tx_clk_cnt <= 16'd0;
                if (tx_bit_cnt == 4'd9) begin
                    tx_busy <= 1'b0;
                    uart_tx <= 1'b1;
                end else begin
                    tx_bit_cnt <= tx_bit_cnt + 4'd1;
                    tx_shift   <= {1'b0, tx_shift[9:1]};
                    uart_tx    <= tx_shift[1];  // next bit
                end
            end else begin
                tx_clk_cnt <= tx_clk_cnt + 16'd1;
            end
        end else if (wb_cyc_i && wb_stb_i && wb_we_i && (wb_adr_i[3:2] == 2'b00) && !wb_ack_o) begin
            // Start TX: shift reg = {1(stop), data[7:0], 0(start)}
            tx_shift   <= {1'b1, wb_dat_i[7:0], 1'b0};
            uart_tx    <= 1'b0;            // start bit
            tx_busy    <= 1'b1;
            tx_bit_cnt <= 4'd0;
            tx_clk_cnt <= 16'd0;
        end
    end

    // =====================================================================
    //  RX
    // =====================================================================
    reg [1:0]  rx_sync;       // metastability synchroniser
    reg [7:0]  rx_data;
    reg        rx_avail;
    reg        rx_active;
    reg [3:0]  rx_bit_cnt;
    reg [15:0] rx_clk_cnt;
    reg [7:0]  rx_shift;

    wire rx_pin = rx_sync[1];

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_sync   <= 2'b11;
            rx_active <= 1'b0;
            rx_avail  <= 1'b0;
            rx_data   <= 8'd0;
            rx_bit_cnt<= 4'd0;
            rx_clk_cnt<= 16'd0;
            rx_shift  <= 8'd0;
        end else begin
            rx_sync <= {rx_sync[0], uart_rx};

            if (!rx_active) begin
                // Detect falling edge (start bit)
                if (rx_pin == 1'b0) begin
                    rx_active  <= 1'b1;
                    rx_clk_cnt <= 16'd0;
                    rx_bit_cnt <= 4'd0;
                end
            end else begin
                if (rx_bit_cnt == 4'd0) begin
                    // In start bit – sample at centre
                    if (rx_clk_cnt == HALF_DIV[15:0] - 16'd1) begin
                        if (rx_pin == 1'b0) begin
                            rx_clk_cnt <= 16'd0;
                            rx_bit_cnt <= 4'd1;
                        end else begin
                            rx_active <= 1'b0;   // false start
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end else begin
                    // Data / stop bits – sample at baud interval
                    if (rx_clk_cnt == BAUD_DIV[15:0] - 16'd1) begin
                        rx_clk_cnt <= 16'd0;
                        if (rx_bit_cnt <= 4'd8) begin
                            rx_shift   <= {rx_pin, rx_shift[7:1]};
                            rx_bit_cnt <= rx_bit_cnt + 4'd1;
                        end else begin
                            // Stop bit
                            rx_data   <= rx_shift;
                            rx_avail  <= 1'b1;
                            rx_active <= 1'b0;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end
            end

            // Clear rx_avail when RXDATA is read
            if (wb_cyc_i && wb_stb_i && !wb_we_i && (wb_adr_i[3:2] == 2'b10) && !wb_ack_o)
                rx_avail <= 1'b0;
        end
    end

    // =====================================================================
    //  Wishbone response
    // =====================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else begin
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                case (wb_adr_i[3:2])
                    2'b00: wb_dat_o <= 32'd0;                   // TXDATA (write-only)
                    2'b01: wb_dat_o <= {31'd0, tx_busy};        // TXSTATUS
                    2'b10: wb_dat_o <= {24'd0, rx_data};        // RXDATA
                    2'b11: wb_dat_o <= {31'd0, rx_avail};       // RXSTATUS
                endcase
            end else begin
                wb_ack_o <= 1'b0;
            end
        end
    end

endmodule
