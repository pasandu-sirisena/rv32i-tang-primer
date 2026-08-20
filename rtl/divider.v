// Sequential restoring integer divider
module divider (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,
    input  wire        is_signed,
    input  wire        is_rem,
    output reg  [31:0] result,
    output reg         busy,
    output reg         done
);

    // State machine registers and working buffers
    reg [4:0]  count;
    reg [31:0] q;
    reg [31:0] r;
    reg [31:0] d;
    reg        neg_result;
    reg        active;
    reg        finishing;

    // Absolute value computation for signed division
    wire [31:0] abs_dvd = (is_signed && dividend[31]) ? (~dividend + 32'd1) : dividend;
    wire [31:0] abs_dvs = (is_signed && divisor[31])  ? (~divisor  + 32'd1) : divisor;

    // Trial subtraction logic for restoring division
    wire [32:0] r_shift = {r[30:0], q[31]};
    wire [32:0] trial   = {1'b0, r_shift[31:0]} - {1'b0, d};

    // Main divider control process
    always @(posedge clk) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            done       <= 1'b0;
            active     <= 1'b0;
            finishing  <= 1'b0;
            result     <= 32'd0;
            q          <= 32'd0;
            r          <= 32'd0;
            d          <= 32'd0;
            count      <= 5'd0;
            neg_result <= 1'b0;
        end else begin
            done <= 1'b0;

            // Start division operation or handle divide by zero
            if (start && !active && !finishing) begin
                if (divisor == 32'd0) begin
                    result <= is_rem ? dividend : 32'hFFFF_FFFF;
                    done   <= 1'b1;
                end else begin
                    q          <= abs_dvd;
                    r          <= 32'd0;
                    d          <= abs_dvs;
                    count      <= 5'd0;
                    active     <= 1'b1;
                    busy       <= 1'b1;
                    finishing  <= 1'b0;
                    neg_result <= is_signed & (is_rem ? dividend[31]
                                                      : (dividend[31] ^ divisor[31]));
                end
            // Execute bit-by-bit division steps
            end else if (active) begin
                if (!trial[32]) begin
                    r <= trial[31:0];
                    q <= {q[30:0], 1'b1};
                end else begin
                    r <= r_shift[31:0];
                    q <= {q[30:0], 1'b0};
                end

                if (count == 5'd31) begin
                    active    <= 1'b0;
                    finishing <= 1'b1;
                end else begin
                    count <= count + 5'd1;
                end
            // Format signed output result
            end else if (finishing) begin
                finishing <= 1'b0;
                busy      <= 1'b0;
                done      <= 1'b1;
                result    <= is_rem ? (neg_result ? (~r + 32'd1) : r)
                                    : (neg_result ? (~q + 32'd1) : q);
            end
        end
    end

endmodule
