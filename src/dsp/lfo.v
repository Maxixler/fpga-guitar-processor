//============================================================================
// LFO — Low Frequency Oscillator
// Generates modulation signals for chorus, tremolo, and other effects.
// Supports sine, triangle, and square waveforms.
// Rate: 0.1 Hz to 15 Hz (controlled by 8-bit parameter)
//============================================================================

`timescale 1ns / 1ps

module lfo (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire [7:0]         rate,          // LFO rate (0=slowest, 255=fastest)
    input  wire [1:0]         waveform,      // 0=sine, 1=triangle, 2=square
    output reg  signed [15:0] lfo_out,       // 16-bit signed LFO output
    output wire [7:0]         phase_out      // Current phase (for debug)
);

    //------------------------------------------------------------------------
    // Phase Accumulator
    // At 48 kHz, to get LFO rate f:
    //   phase_increment = f × 256 / 48000 × 2^16
    // For rate 0→0.1Hz: increment = 0.1 × 256 / 48000 × 65536 ≈ 35
    // For rate 255→15Hz: increment = 15 × 256 / 48000 × 65536 ≈ 5243
    // Linear interpolation: increment = 35 + rate * 20.42 ≈ 35 + rate * 20
    //------------------------------------------------------------------------
    reg [23:0] phase_acc;   // 24-bit phase accumulator
    wire [15:0] phase_inc;

    // Phase increment = 35 + rate * 20
    // rate * 20 = rate * 16 + rate * 4
    assign phase_inc = 16'd35 + {6'd0, rate, 2'd0} + {8'd0, rate[7:0]};
    // Simplified: 35 + rate*5 for more usable range
    // Actually let's do: 35 + rate * 20
    wire [15:0] rate_scaled = {4'd0, rate, 4'd0} + {6'd0, rate, 2'd0};
    // rate*16 + rate*4 = rate*20
    wire [15:0] phase_increment = 16'd35 + rate_scaled;

    always @(posedge clk) begin
        if (rst) begin
            phase_acc <= 24'd0;
        end else if (sample_clk) begin
            phase_acc <= phase_acc + {8'd0, phase_increment};
        end
    end

    // Extract 8-bit phase from accumulator
    wire [7:0] phase = phase_acc[23:16];
    assign phase_out = phase;

    //------------------------------------------------------------------------
    // Waveform Generation
    //------------------------------------------------------------------------

    // Sine wave from LUT
    wire [15:0] sine_value;
    sine_lut u_sine_lut (
        .clk      (clk),
        .phase    (phase),
        .sine_out (sine_value)
    );

    // Triangle wave: linear ramp
    wire signed [15:0] triangle_value;
    wire [7:0] tri_phase = phase;
    assign triangle_value = (tri_phase < 8'd128) ?
        $signed({1'b0, tri_phase, 7'd0}) - 16'sd8192 :    // Rising: 0→+max
        16'sd8191 - $signed({1'b0, (tri_phase - 8'd128), 7'd0}); // Falling: +max→0

    // Square wave
    wire signed [15:0] square_value = (phase < 8'd128) ? 16'sh7FFF : 16'sh8001;

    // Waveform selector
    always @(posedge clk) begin
        if (rst) begin
            lfo_out <= 16'd0;
        end else if (sample_clk) begin
            case (waveform)
                2'd0:    lfo_out <= $signed(sine_value);
                2'd1:    lfo_out <= triangle_value;
                2'd2:    lfo_out <= square_value;
                default: lfo_out <= $signed(sine_value);
            endcase
        end
    end

endmodule
