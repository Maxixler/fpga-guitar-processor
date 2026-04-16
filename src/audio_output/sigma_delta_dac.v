//============================================================================
// Sigma-Delta DAC (1-bit, 2nd Order)
// Converts 24-bit audio to 1-bit PDM stream.
// Operating frequency: system clock (100 MHz → ~2083x oversampling at 48kHz)
// Noise shaping pushes quantization noise out of audible band.
// Effective resolution: ~14 ENOB in audio band
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module sigma_delta_dac (
    input  wire               clk,        // High-speed clock (100 MHz)
    input  wire               rst,
    input  wire               sample_clk, // 48 kHz strobe - new sample
    input  wire signed [23:0] audio_in,   // 24-bit signed input
    output reg                pdm_out,    // 1-bit PDM output
    output wire               amp_enable  // Amplifier shutdown control
);

    // Always enable the amplifier
    assign amp_enable = ~rst;

    // Hold the current sample
    reg signed [23:0] sample_hold;

    always @(posedge clk) begin
        if (rst)
            sample_hold <= 24'd0;
        else if (sample_clk)
            sample_hold <= audio_in;
    end

    //------------------------------------------------------------------------
    // 2nd Order Sigma-Delta Modulator
    // Uses two integrators with feedback from quantizer output
    //------------------------------------------------------------------------
    localparam DAC_WIDTH = 24;

    reg signed [DAC_WIDTH:0] integrator1;  // 25-bit to handle overflow
    reg signed [DAC_WIDTH:0] integrator2;  // 25-bit

    wire signed [DAC_WIDTH:0] dac_feedback;
    wire                      quantizer_out;

    // Quantizer: 1-bit (sign of integrator2)
    assign quantizer_out = ~integrator2[DAC_WIDTH]; // positive → 1, negative → 0

    // DAC feedback: full-scale positive or negative
    assign dac_feedback = quantizer_out ? 
                          {1'b0, {DAC_WIDTH{1'b1}}} :     // +max
                          {1'b1, {DAC_WIDTH{1'b0}}};      // -max (two's complement)

    wire signed [DAC_WIDTH:0] error1;
    wire signed [DAC_WIDTH:0] error2;

    assign error1 = {{1{sample_hold[DAC_WIDTH-1]}}, sample_hold} - dac_feedback;
    assign error2 = integrator1 - dac_feedback;

    always @(posedge clk) begin
        if (rst) begin
            integrator1 <= 0;
            integrator2 <= 0;
            pdm_out     <= 1'b0;
        end else begin
            integrator1 <= integrator1 + error1;
            integrator2 <= integrator2 + error2;
            pdm_out     <= quantizer_out;
        end
    end

endmodule
