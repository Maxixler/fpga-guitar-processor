//============================================================================
// Biquad Filter (IIR, 2nd Order)
// General purpose IIR filter for tone control, EQ, and feedback filtering.
// Transfer function: H(z) = (b0 + b1*z^-1 + b2*z^-2) / (1 + a1*z^-1 + a2*z^-2)
// Direct Form I implementation with extended precision.
// Coefficients in Q2.14 format (14 fractional bits).
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module biquad_filter (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire signed [23:0] audio_in,      // Q1.23 input
    output reg  signed [23:0] audio_out,     // Q1.23 output
    // Coefficients (Q2.14 format, 16-bit signed)
    input  wire signed [15:0] b0,
    input  wire signed [15:0] b1,
    input  wire signed [15:0] b2,
    input  wire signed [15:0] a1,
    input  wire signed [15:0] a2
);

    localparam COEFF_FRAC = 14;

    // State registers (past samples)
    reg signed [23:0] x1, x2;   // x[n-1], x[n-2]
    reg signed [23:0] y1, y2;   // y[n-1], y[n-2]

    // Extended precision accumulators
    wire signed [47:0] fb0, fb1, fb2, fa1, fa2;
    wire signed [47:0] sum_ff, sum_fb, y_full;

    // Feed-forward path: b0*x[n] + b1*x[n-1] + b2*x[n-2]
    assign fb0 = $signed(b0) * audio_in;
    assign fb1 = $signed(b1) * x1;
    assign fb2 = $signed(b2) * x2;
    assign sum_ff = fb0 + fb1 + fb2;

    // Feedback path: -a1*y[n-1] - a2*y[n-2]
    assign fa1 = $signed(a1) * y1;
    assign fa2 = $signed(a2) * y2;
    assign sum_fb = fa1 + fa2;

    // Complete output: (feed-forward - feedback) >> COEFF_FRAC
    assign y_full = (sum_ff - sum_fb) >>> COEFF_FRAC;

    // Saturate to 24-bit
    wire signed [23:0] y_sat;
    assign y_sat = (y_full > $signed(48'sh00000000_3FFFFF)) ? `AUDIO_MAX :
                   (y_full < $signed(48'shFFFFFFFF_C00000)) ? `AUDIO_MIN :
                   y_full[23:0];

    always @(posedge clk) begin
        if (rst) begin
            x1 <= 24'd0; x2 <= 24'd0;
            y1 <= 24'd0; y2 <= 24'd0;
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            // Update delay line
            x2 <= x1;
            x1 <= audio_in;
            y2 <= y1;
            y1 <= y_sat;
            // Output
            audio_out <= y_sat;
        end
    end

endmodule
