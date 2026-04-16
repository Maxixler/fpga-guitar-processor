//============================================================================
// Top-Level Guitar Effects Processor
// Nexys A7-T100 (Artix-7 XC7A100T) FPGA
//
// Audio Path:
//   Guitar → Analog Frontend → XADC (12-bit) → DC Block → Effects Chain →
//   Dithering → Sigma-Delta DAC → PWM Output → Amplifier
//
// Control:
//   SW[6:0]  = Effect enables (Noise Gate, Dist, OD, Delay, Rev, Cho, Trem)
//   SW[15:12]= Master Volume
//   Buttons  = Parameter adjustment
//   7-Seg    = Effect name + parameter value
//   LEDs     = VU Meter
//
// Design: 24-bit internal processing, 48 kHz sample rate
//============================================================================

`timescale 1ns / 1ps
`include "utils/fixed_point_math.vh"

module top_guitar_processor (
    // System
    input  wire        CLK100MHZ,      // 100 MHz oscillator
    input  wire        CPU_RESETN,     // Active-low reset button

    // XADC Analog Input (JXADC header)
    input  wire        vauxp6,         // Auxiliary channel 6 positive
    input  wire        vauxn6,         // Auxiliary channel 6 negative

    // PWM Audio Output
    output wire        AUD_PWM,        // PWM audio signal
    output wire        AUD_SD,         // Audio amplifier shutdown (active low)

    // User Interface
    input  wire [15:0] SW,             // Slide switches
    input  wire        BTNC,           // Center button
    input  wire        BTNU,           // Up button
    input  wire        BTND,           // Down button
    input  wire        BTNL,           // Left button
    input  wire        BTNR,           // Right button
    output wire [15:0] LED,            // LEDs
    output wire [7:0]  AN,             // 7-segment anodes
    output wire [6:0]  SEG,            // 7-segment segments (CA-CG)
    output wire        DP              // 7-segment decimal point
);

    //========================================================================
    // Reset Synchronization
    //========================================================================
    wire rst_n = CPU_RESETN;
    reg  rst_sync1, rst_sync2;
    wire rst = rst_sync2;

    always @(posedge CLK100MHZ) begin
        rst_sync1 <= ~rst_n;
        rst_sync2 <= rst_sync1;
    end

    //========================================================================
    // Sample Clock Generation (48 kHz from 100 MHz)
    //========================================================================
    localparam SAMPLE_DIV = 2083;  // 100MHz / 48kHz ≈ 2083
    reg [11:0] sample_counter;
    reg        sample_clk;

    always @(posedge CLK100MHZ) begin
        if (rst) begin
            sample_counter <= 12'd0;
            sample_clk     <= 1'b0;
        end else begin
            if (sample_counter >= SAMPLE_DIV - 1) begin
                sample_counter <= 12'd0;
                sample_clk     <= 1'b1;
            end else begin
                sample_counter <= sample_counter + 1'b1;
                sample_clk     <= 1'b0;
            end
        end
    end

    //========================================================================
    // Button Debouncers
    //========================================================================
    wire btnc_db, btnu_db, btnd_db, btnl_db, btnr_db;
    wire btnc_pulse, btnu_pulse, btnd_pulse, btnl_pulse, btnr_pulse;

    debouncer u_deb_c (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNC), .btn_out(btnc_db), .btn_pulse(btnc_pulse));
    debouncer u_deb_u (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNU), .btn_out(btnu_db), .btn_pulse(btnu_pulse));
    debouncer u_deb_d (.clk(CLK100MHZ), .rst(rst), .btn_in(BTND), .btn_out(btnd_db), .btn_pulse(btnd_pulse));
    debouncer u_deb_l (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNL), .btn_out(btnl_db), .btn_pulse(btnl_pulse));
    debouncer u_deb_r (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNR), .btn_out(btnr_db), .btn_pulse(btnr_pulse));

    //========================================================================
    // XADC Audio Input
    //========================================================================
    wire signed [23:0] xadc_audio;
    wire               xadc_valid;
    wire [11:0]        xadc_raw;

    xadc_interface u_xadc (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .vauxp6       (vauxp6),
        .vauxn6       (vauxn6),
        .audio_sample (xadc_audio),
        .sample_valid (xadc_valid),
        .raw_adc_data (xadc_raw)
    );

    //========================================================================
    // DC Blocking Filter
    //========================================================================
    wire signed [23:0] dc_blocked;

    dc_blocking_filter u_dc_block (
        .clk        (CLK100MHZ),
        .rst        (rst),
        .sample_clk (sample_clk),
        .audio_in   (xadc_audio),
        .audio_out  (dc_blocked)
    );

    //========================================================================
    // Input Anti-Aliasing Filter (FIR LPF)
    //========================================================================
    wire signed [23:0] filtered_in;
    wire               fir_ready;

    fir_lowpass u_input_fir (
        .clk        (CLK100MHZ),
        .rst        (rst),
        .sample_clk (sample_clk),
        .audio_in   (dc_blocked),
        .audio_out  (filtered_in),
        .ready      (fir_ready)
    );

    //========================================================================
    // Parameter Controller
    //========================================================================
    wire [2:0] selected_effect;
    wire [7:0] display_param;
    wire [6:0] effect_enables = SW[6:0];

    // Parameter wires
    wire [7:0] p_ng_threshold, p_dist_gain, p_dist_tone;
    wire       p_dist_mode;
    wire [7:0] p_od_drive, p_od_mix;
    wire [7:0] p_delay_time, p_delay_feedback, p_delay_mix;
    wire [7:0] p_reverb_decay, p_reverb_mix;
    wire [7:0] p_chorus_rate, p_chorus_depth;
    wire [7:0] p_trem_rate, p_trem_depth;
    wire [1:0] p_trem_wave;

    parameter_controller u_params (
        .clk            (CLK100MHZ),
        .rst            (rst),
        .btn_center     (btnc_pulse),
        .btn_up         (btnu_pulse),
        .btn_down       (btnd_pulse),
        .btn_left       (btnl_pulse),
        .btn_right      (btnr_pulse),
        .effect_enables (effect_enables),
        .selected_effect(selected_effect),
        .display_value  (display_param),
        .ng_threshold   (p_ng_threshold),
        .dist_gain      (p_dist_gain),
        .dist_tone      (p_dist_tone),
        .dist_mode      (p_dist_mode),
        .od_drive       (p_od_drive),
        .od_mix         (p_od_mix),
        .delay_time     (p_delay_time),
        .delay_feedback (p_delay_feedback),
        .delay_mix      (p_delay_mix),
        .reverb_decay   (p_reverb_decay),
        .reverb_mix     (p_reverb_mix),
        .chorus_rate    (p_chorus_rate),
        .chorus_depth   (p_chorus_depth),
        .trem_rate      (p_trem_rate),
        .trem_depth     (p_trem_depth),
        .trem_wave      (p_trem_wave)
    );

    //========================================================================
    // Effects Chain
    //========================================================================
    wire signed [23:0] effects_out;
    wire               gate_status;
    wire [23:0]        vu_in, vu_out;

    effects_chain u_fx_chain (
        .clk                 (CLK100MHZ),
        .rst                 (rst),
        .sample_clk          (sample_clk),
        .audio_in            (filtered_in),
        .audio_out           (effects_out),
        // Enables
        .en_noise_gate       (SW[0]),
        .en_distortion       (SW[1]),
        .en_overdrive        (SW[2]),
        .en_delay            (SW[3]),
        .en_reverb           (SW[4]),
        .en_chorus           (SW[5]),
        .en_tremolo          (SW[6]),
        // Parameters
        .param_ng_threshold  (p_ng_threshold),
        .param_dist_gain     (p_dist_gain),
        .param_dist_tone     (p_dist_tone),
        .param_dist_mode     (p_dist_mode),
        .param_od_drive      (p_od_drive),
        .param_od_mix        (p_od_mix),
        .param_delay_time    (p_delay_time),
        .param_delay_feedback(p_delay_feedback),
        .param_delay_mix     (p_delay_mix),
        .param_reverb_decay  (p_reverb_decay),
        .param_reverb_mix    (p_reverb_mix),
        .param_chorus_rate   (p_chorus_rate),
        .param_chorus_depth  (p_chorus_depth),
        .param_trem_rate     (p_trem_rate),
        .param_trem_depth    (p_trem_depth),
        .param_trem_wave     (p_trem_wave),
        // Status
        .gate_status         (gate_status),
        .vu_level_in         (vu_in),
        .vu_level_out        (vu_out)
    );

    //========================================================================
    // Master Volume Control
    //========================================================================
    wire [3:0] master_vol = SW[15:12];
    wire signed [27:0] vol_scaled = $signed(effects_out) * $signed({1'b0, master_vol});
    wire signed [23:0] vol_out = vol_scaled[27:4]; // Divide by 16

    //========================================================================
    // Output Dithering
    //========================================================================
    wire signed [23:0] dithered_out;

    dithering u_dither (
        .clk        (CLK100MHZ),
        .rst        (rst),
        .sample_clk (sample_clk),
        .audio_in   (vol_out),
        .enable     (1'b1),
        .audio_out  (dithered_out)
    );

    //========================================================================
    // Sigma-Delta DAC (PWM Output)
    //========================================================================
    sigma_delta_dac u_dac (
        .clk        (CLK100MHZ),
        .rst        (rst),
        .sample_clk (sample_clk),
        .audio_in   (dithered_out),
        .pdm_out    (AUD_PWM),
        .amp_enable (AUD_SD)
    );

    //========================================================================
    // VU Meter (LEDs)
    //========================================================================
    vu_meter u_vu (
        .clk        (CLK100MHZ),
        .rst        (rst),
        .sample_clk (sample_clk),
        .level_in   (vu_in),
        .level_out  (vu_out),
        .led_out    (LED)
    );

    //========================================================================
    // Seven-Segment Display
    //========================================================================
    seven_seg_controller u_7seg (
        .clk            (CLK100MHZ),
        .rst            (rst),
        .active_effect  (selected_effect),
        .param_value    (display_param),
        .effect_enables (effect_enables),
        .AN             (AN),
        .SEG            (SEG),
        .DP             (DP)
    );

endmodule
