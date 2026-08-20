`timescale 1ns / 1ps

// Testbench for RV32IM processor top level
module tb_top;

    // 27 MHz clock generator
    reg clk_27mhz;
    initial clk_27mhz = 0;
    always #18.5 clk_27mhz = ~clk_27mhz;

    // Device under test signals
    wire       uart_tx;
    wire [5:0] led_n;

    // Top module instantiation
    top u_dut (
        .clk_27mhz (clk_27mhz),
        .uart_tx   (uart_tx),
        .uart_rx   (1'b1),
        .led_n     (led_n)
    );

    // UART timing parameters for 115200 baud
    localparam BAUD_TICKS = 234;
    localparam CLK_PERIOD = 37;
    localparam BIT_PERIOD = BAUD_TICKS * CLK_PERIOD;

    integer   char_idx;
    reg [7:0] rx_byte;

    initial begin
        char_idx = 0;
    end

    // Task to sample incoming UART byte
    task automatic uart_recv_byte;
        output [7:0] data;
        integer i;
        begin
            @(negedge uart_tx);
            #(BIT_PERIOD / 2);
            for (i = 0; i < 8; i = i + 1) begin
                #BIT_PERIOD;
                data[i] = uart_tx;
            end
            #BIT_PERIOD;
        end
    endtask

    // Background process to receive and print UART stream
    initial begin
        forever begin
            uart_recv_byte(rx_byte);
            char_idx = char_idx + 1;
            if (rx_byte >= 8'h20 && rx_byte < 8'h7F)
                $display("UART RX [%0d]: '%c' (0x%02X)", char_idx - 1, rx_byte, rx_byte);
            else
                $display("UART RX [%0d]: 0x%02X", char_idx - 1, rx_byte);
        end
    end

    // Monitor LED output transitions
    reg [5:0] prev_led;
    integer   led_toggles;
    initial begin
        led_toggles = 0;
        prev_led = 6'h3F;
    end

    always @(led_n) begin
        if (led_n !== prev_led) begin
            $display("Time %0t: LEDs changed to %b", $time, led_n);
            prev_led = led_n;
            led_toggles = led_toggles + 1;
        end
    end

    // Test duration and simulation completion
    initial begin
        $dumpfile("build/waves.vcd");
        $dumpvars(0, tb_top);

        #12_000_000;

        $display("Simulation finished with %0d chars received, %0d LED toggles", char_idx, led_toggles);
        $finish;
    end

endmodule
