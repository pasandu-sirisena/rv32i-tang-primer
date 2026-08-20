// Full-duplex UART peripheral with Wishbone interface
module wb_uart #(
    parameter CLK_FREQ  = 54_000_000,
    parameter BAUD_RATE = 115_200
)(
    // Clock and active-low reset
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

    // Physical UART pins
    output reg         uart_tx,
    input  wire        uart_rx
);

    // Baud rate generator timing constants
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    localparam HALF_DIV = BAUD_DIV / 2;

    // Transmitter registers and state
    reg [9:0]  tx_shift;
    reg [3:0]  tx_bit_cnt;
    reg [15:0] tx_clk_cnt;
    reg        tx_busy;

    // Transmitter state machine
    always @(posedge clk) begin
        if (!rst_n) begin
            uart_tx    <= 1'b1;
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
                    uart_tx    <= tx_shift[1];
                end
            end else begin
                tx_clk_cnt <= tx_clk_cnt + 16'd1;
            end
        end else if (wb_cyc_i && wb_stb_i && wb_we_i && (wb_adr_i[3:2] == 2'b00) && !wb_ack_o) begin
            tx_shift   <= {1'b1, wb_dat_i[7:0], 1'b0};
            uart_tx    <= 1'b0;
            tx_busy    <= 1'b1;
            tx_bit_cnt <= 4'd0;
            tx_clk_cnt <= 16'd0;
        end
    end

    // Receiver registers and state
    reg [1:0]  rx_sync;
    reg [7:0]  rx_data;
    reg        rx_avail;
    reg        rx_active;
    reg [3:0]  rx_bit_cnt;
    reg [15:0] rx_clk_cnt;
    reg [7:0]  rx_shift;

    wire rx_pin = rx_sync[1];

    // Receiver state machine
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
                // Check for incoming start bit falling edge
                if (rx_pin == 1'b0) begin
                    rx_active  <= 1'b1;
                    rx_clk_cnt <= 16'd0;
                    rx_bit_cnt <= 4'd0;
                end
            end else begin
                // Sample at centre of start bit
                if (rx_bit_cnt == 4'd0) begin
                    if (rx_clk_cnt == HALF_DIV[15:0] - 16'd1) begin
                        if (rx_pin == 1'b0) begin
                            rx_clk_cnt <= 16'd0;
                            rx_bit_cnt <= 4'd1;
                        end else begin
                            rx_active <= 1'b0;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                // Sample data bits and stop bit at full baud intervals
                end else begin
                    if (rx_clk_cnt == BAUD_DIV[15:0] - 16'd1) begin
                        rx_clk_cnt <= 16'd0;
                        if (rx_bit_cnt <= 4'd8) begin
                            rx_shift   <= {rx_pin, rx_shift[7:1]};
                            rx_bit_cnt <= rx_bit_cnt + 4'd1;
                        end else begin
                            rx_data   <= rx_shift;
                            rx_avail  <= 1'b1;
                            rx_active <= 1'b0;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end
            end

            // Clear receive flag on data register read
            if (wb_cyc_i && wb_stb_i && !wb_we_i && (wb_adr_i[3:2] == 2'b10) && !wb_ack_o)
                rx_avail <= 1'b0;
        end
    end

    // Wishbone register access decoding
    always @(posedge clk) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else begin
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                case (wb_adr_i[3:2])
                    2'b00: wb_dat_o <= 32'd0;
                    2'b01: wb_dat_o <= {31'd0, tx_busy};
                    2'b10: wb_dat_o <= {24'd0, rx_data};
                    2'b11: wb_dat_o <= {31'd0, rx_avail};
                endcase
            end else begin
                wb_ack_o <= 1'b0;
            end
        end
    end

endmodule
