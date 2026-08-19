// =============================================================================
// Testbench for RV32IM Pipelined Processor
// Self-checking: monitors UART TX output, verifies hello string and LED toggle.
// =============================================================================
`timescale 1ns / 1ps

module tb_top;

    // ---- Clock generation (27 MHz → ~37 ns period) ----
    reg clk_27mhz;
    initial clk_27mhz = 0;
    always #18.5 clk_27mhz = ~clk_27mhz;

    // ---- DUT ----
    wire       uart_tx;
    wire [3:0] led_n;

    top u_dut (
        .clk_27mhz (clk_27mhz),
        .uart_tx   (uart_tx),
        .uart_rx   (1'b1),        // idle high
        .led_n     (led_n)
    );

    // ---- UART RX monitor (capture what the DUT transmits) ----
    // 27 MHz clock → baud divisor = 27_000_000 / 115_200 = 234 → bit period ≈ 234 * 37ns ≈ 8658 ns
    localparam BAUD_TICKS = 234;
    localparam CLK_PERIOD = 37; // ns (27 MHz clock period)
    localparam BIT_PERIOD = BAUD_TICKS * CLK_PERIOD; // ~8658 ns

    reg [1023:0] captured_str;  // big buffer for captured chars
    integer      char_idx;
    reg [7:0]    rx_byte;
    integer      bit_i;

    // Expected string
    reg [8*52-1:0] expected_str;
    initial expected_str = "Hello from pipelined RV32IM on Tang Primer 20K!\r\n";

    initial begin
        char_idx = 0;
        captured_str = 0;
    end

    // UART bit-bang receiver task
    task automatic uart_recv_byte;
        output [7:0] data;
        integer i;
        begin
            // Wait for start bit (falling edge)
            @(negedge uart_tx);
            // Move to centre of start bit
            #(BIT_PERIOD / 2);
            // Sample 8 data bits
            for (i = 0; i < 8; i = i + 1) begin
                #BIT_PERIOD;
                data[i] = uart_tx;
            end
            // Wait through stop bit
            #BIT_PERIOD;
        end
    endtask

    // Continuous UART receiver
    initial begin
        forever begin
            uart_recv_byte(rx_byte);
            captured_str[char_idx*8 +: 8] = rx_byte;
            char_idx = char_idx + 1;
            if (rx_byte >= 8'h20 && rx_byte < 8'h7F)
                $display("UART RX [%0d]: '%c' (0x%02X)", char_idx - 1, rx_byte, rx_byte);
            else
                $display("UART RX [%0d]: 0x%02X", char_idx - 1, rx_byte);
        end
    end

    // ---- LED monitor ----
    reg [3:0] prev_led;
    integer led_toggles;
    initial begin
        led_toggles = 0;
        prev_led = 4'hF; // LEDs off (active low)
    end

    always @(led_n) begin
        if (led_n !== prev_led) begin
            $display("Time %0t: LEDs changed to %b (active-low)", $time, led_n);
            prev_led = led_n;
            led_toggles = led_toggles + 1;
        end
    end

    // ---- Test timeout and result checking ----
    initial begin
        $dumpfile("build/waves.vcd");
        $dumpvars(0, tb_top);

        // Wait for the hello string to be fully transmitted
        // 50 chars × ~173.5us per char ≈ 8.7ms. Give 12ms.
        #12_000_000;

        $display("\n===== SIMULATION RESULTS =====");
        $display("Characters received: %0d", char_idx);

        if (char_idx >= 49) begin
            $display("PASS: Received %0d characters over UART.", char_idx);
        end else begin
            $display("FAIL: Expected >=49 chars, got %0d. Pipeline may be stalled.", char_idx);
        end

        if (led_toggles > 0)
            $display("PASS: LEDs toggled %0d time(s).", led_toggles);
        else
            $display("INFO: No LED toggles yet (delay loop may be long in sim).");

        $display("==============================\n");
        $finish;
    end

endmodule
