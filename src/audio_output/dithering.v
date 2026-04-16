//============================================================================
// TPDF Dithering Module
// Adds Triangular Probability Density Function dither noise before
// bit depth reduction. Uses two LFSR outputs summed together to create
// triangular distribution, which eliminates signal-correlated quantization
// distortion.
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module dithering (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire signed [23:0] audio_in,      // 24-bit input
    input  wire               enable,        // Dithering enable
    output reg  signed [23:0] audio_out      // 24-bit dithered output
);

    // Two LFSR instances for TPDF generation
    wire [31:0] rnd1, rnd2;

    lfsr #(.WIDTH(32), .SEED(32'hCAFEBABE)) u_lfsr1 (
        .clk    (clk),
        .rst    (rst),
        .enable (sample_clk),
        .rnd_out(rnd1),
        .rnd_bit()
    );

    lfsr #(.WIDTH(32), .SEED(32'h12345678)) u_lfsr2 (
        .clk    (clk),
        .rst    (rst),
        .enable (sample_clk),
        .rnd_out(rnd2),
        .rnd_bit()
    );

    // TPDF dither: sum of two uniform random values gives triangular PDF
    // Use only lower bits for small amplitude dither
    // Dither amplitude: ±1 LSB at the target bit depth
    wire signed [7:0] dither1 = rnd1[7:0];
    wire signed [7:0] dither2 = rnd2[7:0];
    wire signed [8:0] tpdf_noise = {dither1[7], dither1} + {dither2[7], dither2};

    // Scale dither to appropriate level (very small relative to signal)
    wire signed [23:0] dither_scaled = {{15{tpdf_noise[8]}}, tpdf_noise};

    wire signed [24:0] sum = {audio_in[23], audio_in} + {dither_scaled[23], dither_scaled};

    // Saturate
    wire signed [23:0] dithered = (sum > $signed(25'sh3FFFFF)) ? `AUDIO_MAX :
                                  (sum < $signed(25'shC00000)) ? `AUDIO_MIN :
                                  sum[23:0];

    always @(posedge clk) begin
        if (rst) begin
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            audio_out <= enable ? dithered : audio_in;
        end
    end

endmodule
