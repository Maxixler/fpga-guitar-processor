//============================================================================
// LFSR — Linear Feedback Shift Register
// Generates pseudo-random bit sequences for dithering and noise generation.
// Uses maximal-length polynomial for 32-bit: x^32 + x^22 + x^2 + x + 1
//============================================================================

`timescale 1ns / 1ps

module lfsr #(
    parameter WIDTH = 32,
    parameter SEED  = 32'hDEADBEEF   // Non-zero seed
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             enable,    // Clock enable (e.g., sample_clk strobe)
    output wire [WIDTH-1:0] rnd_out,   // Full random output
    output wire             rnd_bit    // Single random bit
);

    reg [WIDTH-1:0] lfsr_reg;

    // Feedback taps for maximal-length sequence
    // x^32 + x^22 + x^2 + x + 1
    wire feedback = lfsr_reg[31] ^ lfsr_reg[21] ^ lfsr_reg[1] ^ lfsr_reg[0];

    always @(posedge clk) begin
        if (rst) begin
            lfsr_reg <= SEED;
        end else if (enable) begin
            lfsr_reg <= {lfsr_reg[WIDTH-2:0], feedback};
        end
    end

    assign rnd_out = lfsr_reg;
    assign rnd_bit = lfsr_reg[0];

endmodule
