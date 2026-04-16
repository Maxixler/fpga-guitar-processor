//============================================================================
// Noise Gate
// Mutes the audio signal when it falls below a threshold level.
// Uses envelope follower with configurable attack/release times
// for smooth gain transitions (no clicks/pops).
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module noise_gate (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire               bypass,        // Bypass effect
    input  wire signed [23:0] audio_in,      // Q1.23 input
    input  wire [7:0]         threshold,     // Gate threshold (0=sensitive, 255=high)
    output reg  signed [23:0] audio_out,     // Q1.23 output
    output wire               gate_open      // Gate status indicator
);

    //------------------------------------------------------------------------
    // Envelope Follower
    // Tracks the peak level of the signal with fast attack, slow release
    // Attack: ~0.5ms, Release: ~50ms
    //------------------------------------------------------------------------
    reg [23:0] envelope;

    // Attack coefficient: fast (1/24 samples ≈ 0.5ms @ 48kHz)
    // Release coefficient: slow (1/2400 samples ≈ 50ms @ 48kHz)
    localparam [11:0] ATTACK_COEFF  = 12'd683;   // 1/24 * 16384
    localparam [11:0] RELEASE_COEFF = 12'd7;      // 1/2400 * 16384

    wire [23:0] abs_input = audio_in[23] ? (~audio_in + 1'b1) : audio_in;

    always @(posedge clk) begin
        if (rst) begin
            envelope <= 24'd0;
        end else if (sample_clk) begin
            if (abs_input > envelope) begin
                // Attack: fast rise
                envelope <= envelope + ((abs_input - envelope) >>> 4);
            end else begin
                // Release: slow decay
                envelope <= envelope - (envelope >>> 11);
            end
        end
    end

    //------------------------------------------------------------------------
    // Threshold Comparison
    // Convert 8-bit threshold to 24-bit comparison level
    //------------------------------------------------------------------------
    wire [23:0] thresh_level = {threshold, 16'd0};  // Scale to 24-bit range
    wire        is_above = (envelope > thresh_level);
    assign gate_open = is_above;

    //------------------------------------------------------------------------
    // Smooth Gain Control
    // Ramp gain up/down to avoid clicks
    //------------------------------------------------------------------------
    reg [15:0] gate_gain;   // 0 = muted, 16'hFFFF = full volume

    always @(posedge clk) begin
        if (rst) begin
            gate_gain <= 16'hFFFF;
        end else if (sample_clk) begin
            if (is_above) begin
                // Open gate: ramp up quickly
                if (gate_gain < 16'hFF00)
                    gate_gain <= gate_gain + 16'd256;
                else
                    gate_gain <= 16'hFFFF;
            end else begin
                // Close gate: ramp down smoothly
                if (gate_gain > 16'd64)
                    gate_gain <= gate_gain - 16'd64;
                else
                    gate_gain <= 16'd0;
            end
        end
    end

    //------------------------------------------------------------------------
    // Apply Gate
    //------------------------------------------------------------------------
    wire signed [39:0] gated = $signed(audio_in) * $signed({1'b0, gate_gain});
    wire signed [23:0] gated_out = gated[39:16]; // Divide by 65536

    always @(posedge clk) begin
        if (rst) begin
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            audio_out <= bypass ? audio_in : gated_out;
        end
    end

endmodule
