//============================================================================
// Distortion Effect
// Hard clipping and soft clipping (polynomial approximation of tanh).
// Features adjustable gain (1x-32x) and tone control.
//
// Soft clip transfer function: y = x - x³/3 (normalized to ±1)
// This approximates tanh(x) for |x| < 1, giving a warm overdrive character.
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module distortion (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire               bypass,        // Bypass effect
    input  wire signed [23:0] audio_in,      // Q1.23 input
    input  wire [7:0]         gain,          // Distortion gain (0=clean, 255=heavy)
    input  wire [7:0]         tone,          // Tone control (0=dark, 255=bright)
    input  wire               clip_mode,     // 0=soft clip, 1=hard clip
    output reg  signed [23:0] audio_out,     // Q1.23 output
    output wire               ready
);

    assign ready = 1'b1;

    //------------------------------------------------------------------------
    // Stage 1: Pre-Gain
    // Gain range: 1x (gain=0) to 32x (gain=255)
    // gain_mult = 1 + gain * 31/255 ≈ 1 + gain/8
    //------------------------------------------------------------------------
    wire [4:0] gain_shift = gain[7:3]; // 0-31
    wire signed [47:0] gained = $signed(audio_in) * $signed({1'b0, 5'd1 + gain_shift, 18'd0});
    wire signed [23:0] gained_scaled = gained[41:18]; // Scale back

    // Simple gain: shift left by gain_shift amount (clamped)
    reg signed [47:0] pre_gained;
    always @(*) begin
        case (gain[7:5])
            3'd0: pre_gained = {{24{audio_in[23]}}, audio_in};           // 1x
            3'd1: pre_gained = {{23{audio_in[23]}}, audio_in, 1'd0};     // 2x
            3'd2: pre_gained = {{22{audio_in[23]}}, audio_in, 2'd0};     // 4x
            3'd3: pre_gained = {{21{audio_in[23]}}, audio_in, 3'd0};     // 8x
            3'd4: pre_gained = {{20{audio_in[23]}}, audio_in, 4'd0};     // 16x
            3'd5: pre_gained = {{19{audio_in[23]}}, audio_in, 5'd0};     // 32x
            3'd6: pre_gained = {{18{audio_in[23]}}, audio_in, 6'd0};     // 64x
            3'd7: pre_gained = {{17{audio_in[23]}}, audio_in, 7'd0};     // 128x
        endcase
    end

    //------------------------------------------------------------------------
    // Stage 2: Clipping
    //------------------------------------------------------------------------
    reg signed [23:0] clipped;

    // Soft clip: y = (3/2) * (x - x^3/3) for |x| <= 1 (already normalized)
    // Simplified: y = x - x^3/3
    // In fixed point: y = x - (x*x*x) >> (2*FRAC_BITS) / 3

    wire signed [23:0] clamped_input;
    // First clamp the gained signal to ±1.0 range for soft clip calculation
    assign clamped_input = (pre_gained > $signed(48'sh3FFFFF)) ? `AUDIO_MAX :
                           (pre_gained < $signed(48'shFFC00000)) ? `AUDIO_MIN :
                           pre_gained[23:0];

    // x² calculation (Q1.23 × Q1.23 = Q2.46, keep as Q1.23)
    wire signed [47:0] x_squared = $signed(clamped_input) * $signed(clamped_input);
    wire signed [23:0] x_sq = x_squared[46:23]; // Q1.23

    // x³ calculation  
    wire signed [47:0] x_cubed = $signed(x_sq) * $signed(clamped_input);
    wire signed [23:0] x_cb = x_cubed[46:23]; // Q1.23

    // x³/3 ≈ x³ * 0.333 ≈ x³ * (1/4 + 1/16 + 1/64) = x³ * 0.328125
    // Better: x³/3 ≈ x³ >> 2 + x³ >> 4 + x³ >> 6
    wire signed [23:0] x_cb_div3 = (x_cb >>> 2) + (x_cb >>> 4) + (x_cb >>> 6);

    // Soft clipped output: y = x - x³/3
    wire signed [24:0] soft_clip_full = {clamped_input[23], clamped_input} - 
                                         {x_cb_div3[23], x_cb_div3};
    wire signed [23:0] soft_clipped = (soft_clip_full > $signed(25'sh3FFFFF)) ? `AUDIO_MAX :
                                      (soft_clip_full < $signed(25'shC00000)) ? `AUDIO_MIN :
                                      soft_clip_full[23:0];

    // Hard clipped output: simple clamp at ±threshold
    // Threshold is inverse of gain for harder clip at higher gain
    wire signed [23:0] hard_thresh = {1'b0, ~gain[7:1], 16'hFFFF};
    wire signed [23:0] hard_clipped;
    assign hard_clipped = (pre_gained > $signed({24'd0, hard_thresh})) ? hard_thresh :
                          (pre_gained < -$signed({24'd0, hard_thresh})) ? -hard_thresh :
                          pre_gained[23:0];

    always @(*) begin
        clipped = clip_mode ? hard_clipped : soft_clipped;
    end

    //------------------------------------------------------------------------
    // Stage 3: Tone Control (1st order IIR LPF)
    // Variable cutoff based on tone parameter
    // Higher tone = brighter (more highs pass through)
    //------------------------------------------------------------------------
    reg signed [23:0] tone_filtered;
    reg signed [23:0] tone_prev;

    // Tone coefficient: α = tone/256 
    // LPF: y[n] = α*x[n] + (1-α)*y[n-1]
    wire signed [31:0] tone_x = $signed(clipped) * $signed({1'b0, tone, 7'd0});
    wire signed [31:0] tone_y = $signed(tone_prev) * $signed({1'b0, ~tone, 7'd0});
    wire signed [31:0] tone_sum = (tone_x + tone_y) >>> 15;

    always @(posedge clk) begin
        if (rst) begin
            tone_prev     <= 24'd0;
            tone_filtered <= 24'd0;
        end else if (sample_clk) begin
            tone_filtered <= tone_sum[23:0];
            tone_prev     <= tone_sum[23:0];
        end
    end

    //------------------------------------------------------------------------
    // Output Selection
    //------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            audio_out <= bypass ? audio_in : tone_filtered;
        end
    end

endmodule
