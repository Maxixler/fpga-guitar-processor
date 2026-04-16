//============================================================================
// Overdrive Effect
// Asymmetric soft clipping to emulate tube amplifier character.
// Positive and negative half-waves are clipped differently,
// producing even-order harmonics (2nd harmonic dominant)
// that give the warm "tube" sound.
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module overdrive (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire               bypass,        // Bypass effect
    input  wire signed [23:0] audio_in,      // Q1.23 input
    input  wire [7:0]         drive,         // Drive amount (0=clean, 255=heavy)
    input  wire [7:0]         mix,           // Dry/Wet mix (0=dry, 255=wet)
    output reg  signed [23:0] audio_out,     // Q1.23 output
    output wire               ready
);

    assign ready = 1'b1;

    //------------------------------------------------------------------------
    // Pre-gain based on drive parameter
    //------------------------------------------------------------------------
    reg signed [47:0] pre_gained;

    always @(*) begin
        case (drive[7:6])
            2'd0: pre_gained = {{24{audio_in[23]}}, audio_in};           // 1x
            2'd1: pre_gained = {{22{audio_in[23]}}, audio_in, 2'd0};     // 4x
            2'd2: pre_gained = {{20{audio_in[23]}}, audio_in, 4'd0};     // 16x
            2'd3: pre_gained = {{19{audio_in[23]}}, audio_in, 5'd0};     // 32x
        endcase
    end

    // Fine gain adjustment using lower bits
    wire signed [47:0] fine_gain = pre_gained + (pre_gained >>> (8 - drive[5:4]));

    // Clamp to reasonable range before clipping
    wire signed [23:0] gained_clamped;
    assign gained_clamped = (fine_gain > $signed(48'sh00000000_7FFFFF)) ? 24'sh7FFFFF :
                            (fine_gain < $signed(48'shFFFFFFFF_800000)) ? 24'sh800001 :
                            fine_gain[23:0];

    //------------------------------------------------------------------------
    // Asymmetric Soft Clipping
    // Positive half: y = x - x²/4 (gentler compression)
    // Negative half: y = x - x²/2 (harder compression)
    // This creates 2nd harmonic content → warm tube character
    //------------------------------------------------------------------------

    wire is_positive = ~gained_clamped[23];

    // x² (always positive)
    wire signed [47:0] x_sq_full = $signed(gained_clamped) * $signed(gained_clamped);
    wire signed [23:0] x_sq = x_sq_full[46:23];

    // Positive clip: y = x - x²/4
    wire signed [23:0] x_sq_pos = x_sq >>> 2;
    wire signed [24:0] pos_clip = {gained_clamped[23], gained_clamped} - 
                                   {x_sq_pos[23], x_sq_pos};

    // Negative clip: y = x + x²/2 (note: for negative x, x²/2 is added)
    wire signed [23:0] x_sq_neg = x_sq >>> 1;
    wire signed [24:0] neg_clip = {gained_clamped[23], gained_clamped} + 
                                   {x_sq_neg[23], x_sq_neg};

    // Select based on polarity
    wire signed [24:0] clipped = is_positive ? pos_clip : neg_clip;

    // Saturate
    wire signed [23:0] clipped_sat;
    assign clipped_sat = (clipped > $signed(25'sh3FFFFF)) ? `AUDIO_MAX :
                         (clipped < $signed(25'shC00000)) ? `AUDIO_MIN :
                         clipped[23:0];

    //------------------------------------------------------------------------
    // Dry/Wet Mix
    // mix=0: 100% dry, mix=255: 100% wet
    //------------------------------------------------------------------------
    wire signed [31:0] wet_part = $signed(clipped_sat) * $signed({1'b0, mix});
    wire signed [31:0] dry_part = $signed(audio_in) * $signed({1'b0, ~mix});
    wire signed [31:0] mixed = (wet_part + dry_part) >>> 8;

    wire signed [23:0] mixed_sat;
    assign mixed_sat = (mixed > $signed(32'sh003FFFFF)) ? `AUDIO_MAX :
                       (mixed < $signed(32'shFFC00000)) ? `AUDIO_MIN :
                       mixed[23:0];

    //------------------------------------------------------------------------
    // Output
    //------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            audio_out <= bypass ? audio_in : mixed_sat;
        end
    end

endmodule
