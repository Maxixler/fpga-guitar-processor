//============================================================================
// Effects Chain — Serial Effects Router
// Routes audio through all enabled effects in series:
// Noise Gate → Distortion → Overdrive → Delay → Reverb → Chorus → Tremolo
//
// Each effect can be individually enabled/disabled via switch inputs.
// Parameters are routed to the selected effect for adjustment.
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module effects_chain (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire signed [23:0] audio_in,      // Q1.23 input
    output wire signed [23:0] audio_out,     // Q1.23 output

    // Effect Enable Switches
    input  wire               en_noise_gate,  // SW[0]
    input  wire               en_distortion,  // SW[1]
    input  wire               en_overdrive,   // SW[2]
    input  wire               en_delay,       // SW[3]
    input  wire               en_reverb,      // SW[4]
    input  wire               en_chorus,      // SW[5]
    input  wire               en_tremolo,     // SW[6]

    // Parameters (active effect selected by parameter_controller)
    input  wire [7:0]         param_ng_threshold,
    input  wire [7:0]         param_dist_gain,
    input  wire [7:0]         param_dist_tone,
    input  wire               param_dist_mode,    // 0=soft, 1=hard
    input  wire [7:0]         param_od_drive,
    input  wire [7:0]         param_od_mix,
    input  wire [7:0]         param_delay_time,
    input  wire [7:0]         param_delay_feedback,
    input  wire [7:0]         param_delay_mix,
    input  wire [7:0]         param_reverb_decay,
    input  wire [7:0]         param_reverb_mix,
    input  wire [7:0]         param_chorus_rate,
    input  wire [7:0]         param_chorus_depth,
    input  wire [7:0]         param_trem_rate,
    input  wire [7:0]         param_trem_depth,
    input  wire [1:0]         param_trem_wave,

    // Status outputs
    output wire               gate_status,
    output wire [23:0]        vu_level_in,
    output wire [23:0]        vu_level_out
);

    //========================================================================
    // Inter-stage audio busses
    //========================================================================
    wire signed [23:0] stage0_out;  // After noise gate
    wire signed [23:0] stage1_out;  // After distortion
    wire signed [23:0] stage2_out;  // After overdrive
    wire signed [23:0] stage3_out;  // After delay
    wire signed [23:0] stage4_out;  // After reverb
    wire signed [23:0] stage5_out;  // After chorus
    wire signed [23:0] stage6_out;  // After tremolo

    //========================================================================
    // Stage 0: Noise Gate
    //========================================================================
    noise_gate u_noise_gate (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (~en_noise_gate),
        .audio_in   (audio_in),
        .threshold  (param_ng_threshold),
        .audio_out  (stage0_out),
        .gate_open  (gate_status)
    );

    //========================================================================
    // Stage 1: Distortion
    //========================================================================
    distortion u_distortion (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (~en_distortion),
        .audio_in   (stage0_out),
        .gain       (param_dist_gain),
        .tone       (param_dist_tone),
        .clip_mode  (param_dist_mode),
        .audio_out  (stage1_out),
        .ready      ()
    );

    //========================================================================
    // Stage 2: Overdrive
    //========================================================================
    overdrive u_overdrive (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (~en_overdrive),
        .audio_in   (stage1_out),
        .drive      (param_od_drive),
        .mix        (param_od_mix),
        .audio_out  (stage2_out),
        .ready      ()
    );

    //========================================================================
    // Stage 3: Delay
    //========================================================================
    delay u_delay (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (~en_delay),
        .audio_in   (stage2_out),
        .delay_time (param_delay_time),
        .feedback   (param_delay_feedback),
        .mix        (param_delay_mix),
        .audio_out  (stage3_out),
        .ready      ()
    );

    //========================================================================
    // Stage 4: Reverb
    //========================================================================
    reverb u_reverb (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (~en_reverb),
        .audio_in   (stage3_out),
        .decay      (param_reverb_decay),
        .mix        (param_reverb_mix),
        .audio_out  (stage4_out),
        .ready      ()
    );

    //========================================================================
    // Stage 5: Chorus
    //========================================================================
    chorus u_chorus (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (~en_chorus),
        .audio_in   (stage4_out),
        .rate       (param_chorus_rate),
        .depth      (param_chorus_depth),
        .audio_out  (stage5_out),
        .ready      ()
    );

    //========================================================================
    // Stage 6: Tremolo
    //========================================================================
    tremolo u_tremolo (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (~en_tremolo),
        .audio_in   (stage5_out),
        .rate       (param_trem_rate),
        .depth      (param_trem_depth),
        .waveform   (param_trem_wave),
        .audio_out  (stage6_out),
        .ready      ()
    );

    //========================================================================
    // Output
    //========================================================================
    assign audio_out = stage6_out;

    // VU level outputs (absolute values)
    assign vu_level_in  = audio_in[23]  ? (~audio_in  + 1'b1) : audio_in;
    assign vu_level_out = stage6_out[23] ? (~stage6_out + 1'b1) : stage6_out;

endmodule
