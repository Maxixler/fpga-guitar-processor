//============================================================================
// Tremolo Effect
// Amplitude modulation using LFO.
// Multiplies the audio signal by a time-varying gain controlled by LFO.
// Supports sine, triangle, and square waveforms.
//
// Rate: 1 Hz - 15 Hz
// Depth: 0% (no effect) to 100% (full amplitude modulation)
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module tremolo (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire               bypass,        // Bypass effect
    input  wire signed [23:0] audio_in,      // Q1.23 input
    input  wire [7:0]         rate,          // Tremolo rate
    input  wire [7:0]         depth,         // Modulation depth (0=none, 255=full)
    input  wire [1:0]         waveform,      // 0=sine, 1=triangle, 2=square
    output reg  signed [23:0] audio_out,     // Q1.23 output
    output wire               ready
);

    assign ready = 1'b1;

    //------------------------------------------------------------------------
    // LFO Instance
    //------------------------------------------------------------------------
    wire signed [15:0] lfo_value;

    lfo u_trem_lfo (
        .clk       (clk),
        .rst       (rst),
        .sample_clk(sample_clk),
        .rate      (rate),
        .waveform  (waveform),
        .lfo_out   (lfo_value),
        .phase_out ()
    );

    //------------------------------------------------------------------------
    // Gain Modulation
    // gain = 1.0 - depth * (1 - lfo_normalized) / 2
    // Where lfo_normalized is 0.0 to 1.0 (shifted from ±1.0)
    //
    // Simplified: gain = 1.0 - (depth/256) * (0.5 - lfo/65536)
    //
    // In practice: gain_factor = 32768 + lfo_scaled
    // Where lfo_scaled = lfo * depth / 512
    //------------------------------------------------------------------------

    // Offset LFO to unipolar: 0 to 65535
    wire [15:0] lfo_unipolar = lfo_value + 16'sh7FFF;

    // Scale by depth: modulated_gain = 65535 - depth * (65535 - lfo_unipolar) / 256
    wire [23:0] depth_scale = {8'd0, ~depth} + 24'd1; // 256 - depth (inverted)
    wire [31:0] gain_offset = ({16'd0, lfo_unipolar} * {24'd0, depth}) >>> 8;
    wire [15:0] mod_gain = {8'd0, ~depth} + gain_offset[15:0]; // Base + modulation

    // Clamp gain
    wire [15:0] gain_clamped = (mod_gain > 16'hFFFF) ? 16'hFFFF : mod_gain;

    //------------------------------------------------------------------------
    // Apply Gain
    //------------------------------------------------------------------------
    wire signed [39:0] modulated = $signed(audio_in) * $signed({1'b0, gain_clamped});
    wire signed [23:0] mod_out = modulated[39:16]; // ÷65536

    always @(posedge clk) begin
        if (rst) begin
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            audio_out <= bypass ? audio_in : mod_out;
        end
    end

endmodule
