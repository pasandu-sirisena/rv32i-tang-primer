// Dual-port block RAM memory with Wishbone data access
module wb_bram (
    // Clock and active-low reset
    input  wire        clk,
    input  wire        rst_n,

    // Port A synchronous instruction fetch
    input  wire [12:0] iaddr,
    input  wire        ice,
    output reg  [31:0] irdata,

    // Port B Wishbone data memory slave
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o
);

    // 8 KB memory array (2048 words of 32 bits)
    reg [31:0] mem [0:2047];

    // Load initial memory content from hex file
    initial $readmemh("rtl/firmware.hex", mem);

    // Word address decoding for Wishbone port
    wire [10:0] waddr = wb_adr_i[12:2];

    // Port A instruction fetch process
    always @(posedge clk) begin
        if (ice)
            irdata <= mem[iaddr[10:0]];
    end

    // Port B Wishbone read and write process
    always @(posedge clk) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
            wb_ack_o <= 1'b1;
            wb_dat_o <= mem[waddr];
            if (wb_we_i)
                mem[waddr] <= wb_dat_i;
        end else begin
            wb_ack_o <= 1'b0;
        end
    end

endmodule
