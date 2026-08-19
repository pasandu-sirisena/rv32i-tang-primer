// =============================================================================
// RV32IM Sequential Restoring Divider — 33-cycle (32 + 1 output)
// Supports DIV, DIVU, REM, REMU.
// =============================================================================
module divider (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,
    input  wire        is_signed,
    input  wire        is_rem,      // 1 = return remainder, 0 = return quotient
    output reg  [31:0] result,
    output reg         busy,
    output reg         done
);

    reg [4:0]  count;
    reg [31:0] q;          // working quotient (also holds abs dividend initially)
    reg [31:0] r;          // working remainder
    reg [31:0] d;          // absolute divisor
    reg        neg_result; // negate final result?
    reg        active;
    reg        finishing;

    wire [31:0] abs_dvd = (is_signed && dividend[31]) ? (~dividend + 32'd1) : dividend;
    wire [31:0] abs_dvs = (is_signed && divisor[31])  ? (~divisor  + 32'd1) : divisor;

    // Trial subtraction: shift R left by 1, bring in MSB of Q, subtract D
    wire [32:0] r_shift = {r[30:0], q[31]};
    wire [32:0] trial   = {1'b0, r_shift[31:0]} - {1'b0, d};

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

            if (start && !active && !finishing) begin
                if (divisor == 32'd0) begin
                    // Division by zero: quot = -1, rem = dividend (per RISC-V spec)
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
            end else if (active) begin
                // One step of restoring division
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
            end else if (finishing) begin
                // Output cycle: q and r hold the unsigned quotient / remainder
                finishing <= 1'b0;
                busy      <= 1'b0;
                done      <= 1'b1;
                result    <= is_rem ? (neg_result ? (~r + 32'd1) : r)
                                    : (neg_result ? (~q + 32'd1) : q);
            end
        end
    end

endmodule
