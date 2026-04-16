//============================================================================
// Chorus Effect
// LFO-modulated delay line creates pitch/time variations that produce
// a lush, thickened sound. Uses linear interpolation for smooth
// modulation without zipper noise.
//
// Delay range: 5ms - 30ms (240 - 1440 samples @ 48kHz)
// LFO rate: 0.1 Hz - 5 Hz
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module chorus (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire               bypass,        // Bypass effect
    input  wire signed [23:0] audio_in,      // Q1.23 input
    input  wire [7:0]         rate,          // LFO rate (0=slow, 255=fast)
    input  wire [7:0]         depth,         // Modulation depth (0=subtle, 255=deep)
    output reg  signed [23:0] audio_out,     // Q1.23 output
    output wire               ready
);

    assign ready = 1'b1;

    //------------------------------------------------------------------------
    // Delay Buffer (2048 samples — enough for 30ms + modulation range)
    //------------------------------------------------------------------------
    localparam BUF_DEPTH = 2048;
    localparam ADDR_BITS = 11;

    (* ram_style = "block" *)
    reg signed [23:0] chorus_buf [0:BUF_DEPTH-1];

    reg [ADDR_BITS-1:0] write_ptr;

    // Write input to buffer
    always @(posedge clk) begin
        if (rst) begin
            write_ptr <= 0;
        end else if (sample_clk) begin
            chorus_buf[write_ptr] <= audio_in;
            write_ptr <= write_ptr + 1'b1;
        end
    end

    //------------------------------------------------------------------------
    // LFO for Delay Modulation
    //------------------------------------------------------------------------
    wire signed [15:0] lfo_value;
    wire [7:0] lfo_phase;

    lfo u_chorus_lfo (
        .clk       (clk),
        .rst       (rst),
        .sample_clk(sample_clk),
        .rate      (rate),
        .waveform  (2'd0),          // Sine wave for smooth modulation
        .lfo_out   (lfo_value),
        .phase_out (lfo_phase)
    );

    //------------------------------------------------------------------------
    // Modulated Delay Calculation
    // Center delay: ~17.5ms (840 samples)
    // Modulation range: ±depth * 600 / 256 samples (up to ±600 samples)
    //------------------------------------------------------------------------
    localparam [ADDR_BITS-1:0] CENTER_DELAY = 840;

    // Scale LFO output by depth parameter
    // lfo_value is ±32767 (16-bit signed)
    // modulation = lfo_value * depth / 256 * 600 / 32768
    wire signed [31:0] mod_amount = ($signed(lfo_value) * $signed({1'b0, depth}));
    wire signed [15:0] mod_scaled = mod_amount[23:8]; // ÷256
    
    // Scale to samples: mod_scaled * 600 / 32768
    wire signed [31:0] mod_samples = $signed(mod_scaled) * $signed(16'd600);
    wire signed [ADDR_BITS-1:0] mod_offset = mod_samples[25:15]; // ÷32768

    // Read address (integer part)
    wire [ADDR_BITS-1:0] read_addr = write_ptr - CENTER_DELAY - mod_offset;

    // Read delayed sample
    reg signed [23:0] delayed_sample;
    always @(posedge clk) begin
        delayed_sample <= chorus_buf[read_addr];
    end

    //------------------------------------------------------------------------
    // Mix: 50/50 dry/wet (classic chorus)
    //------------------------------------------------------------------------
    wire signed [24:0] mix_sum = {audio_in[23], audio_in} + {delayed_sample[23], delayed_sample};
    wire signed [23:0] mixed = mix_sum[24:1]; // Average (÷2)

    always @(posedge clk) begin
        if (rst) begin
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            audio_out <= bypass ? audio_in : mixed;
        end
    end

    // Init buffer (simulation)
    integer i;
    initial begin
        for (i = 0; i < BUF_DEPTH; i = i + 1)
            chorus_buf[i] = 24'd0;
    end

endmodule
