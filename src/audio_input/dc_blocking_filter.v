//============================================================================
// DC Blocking Filter
// First-order IIR high-pass filter to remove DC offset from audio signal.
// Transfer function: H(z) = (1 - z^-1) / (1 - α·z^-1)
// Implementation: y[n] = x[n] - x[n-1] + α·y[n-1]
// α = 0.995 ≈ 8159/8192 (Q1.13 fixed-point)
// Cutoff frequency: ~3.8 Hz at 48 kHz sample rate
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module dc_blocking_filter (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire signed [23:0] audio_in,      // Q1.23 input
    output reg  signed [23:0] audio_out      // Q1.23 output (DC removed)
);

    // α = 0.995 in Q1.13 ≈ 8159
    localparam signed [13:0] ALPHA = 14'sd8159;  // 0.995 × 8192
    localparam ALPHA_SHIFT = 13;

    reg signed [23:0] x_prev;      // x[n-1]
    reg signed [23:0] y_prev;      // y[n-1]

    wire signed [23:0] x_diff;     // x[n] - x[n-1]
    wire signed [47:0] alpha_y;    // α × y[n-1]
    wire signed [47:0] y_full;     // Full precision result
    wire signed [23:0] y_sat;      // Saturated output

    assign x_diff  = audio_in - x_prev;
    assign alpha_y = $signed(ALPHA) * y_prev;
    assign y_full  = {{24{x_diff[23]}}, x_diff} + (alpha_y >>> ALPHA_SHIFT);

    // Saturate to 24-bit
    assign y_sat = (y_full > $signed(48'sh00000000_3FFFFF)) ? `AUDIO_MAX :
                   (y_full < $signed(48'shFFFFFFFF_C00000)) ? `AUDIO_MIN :
                   y_full[23:0];

    always @(posedge clk) begin
        if (rst) begin
            x_prev    <= 24'd0;
            y_prev    <= 24'd0;
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            x_prev    <= audio_in;
            y_prev    <= y_sat;
            audio_out <= y_sat;
        end
    end

endmodule
