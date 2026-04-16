//============================================================================
// FIR Low-Pass Filter (31-tap)
// Hamming window design, cutoff ~20 kHz at 48 kHz sample rate.
// Uses pipelined multiply-accumulate for timing closure.
// Symmetric coefficients exploited to halve multiplications.
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module fir_lowpass (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire signed [23:0] audio_in,      // Q1.23 input
    output reg  signed [23:0] audio_out,     // Q1.23 output
    output reg                ready          // Output valid
);

    // Number of taps (must be odd for symmetric FIR, Type I)
    localparam TAPS = 31;
    localparam HALF = (TAPS - 1) / 2;  // 15

    // Delay line
    reg signed [23:0] delay_line [0:TAPS-1];
    integer i;

    // Coefficients in Q2.14 (16-bit signed)
    // 31-tap Hamming window FIR, fc = 20kHz @ fs = 48kHz
    // Most energy passes through (mild anti-aliasing)
    reg signed [15:0] coeff [0:HALF];

    initial begin
        coeff[ 0] = 16'sd5;       // h[0] = h[30]
        coeff[ 1] = -16'sd12;     // h[1] = h[29]
        coeff[ 2] = -16'sd18;     // h[2] = h[28]
        coeff[ 3] = 16'sd35;      // h[3] = h[27]
        coeff[ 4] = 16'sd28;      // h[4] = h[26]
        coeff[ 5] = -16'sd72;     // h[5] = h[25]
        coeff[ 6] = -16'sd38;     // h[6] = h[24]
        coeff[ 7] = 16'sd142;     // h[7] = h[23]
        coeff[ 8] = 16'sd42;      // h[8] = h[22]
        coeff[ 9] = -16'sd280;    // h[9] = h[21]
        coeff[10] = -16'sd30;     // h[10] = h[20]
        coeff[11] = 16'sd640;     // h[11] = h[19]
        coeff[12] = -16'sd58;     // h[12] = h[18]
        coeff[13] = -16'sd2048;   // h[13] = h[17]
        coeff[14] = 16'sd4096;    // h[14] = h[16]
        coeff[15] = 16'sd13926;   // h[15] = center tap (≈0.85)
    end

    // Pipeline control
    localparam ST_IDLE     = 3'd0;
    localparam ST_SHIFT    = 3'd1;
    localparam ST_MAC      = 3'd2;
    localparam ST_CENTER   = 3'd3;
    localparam ST_OUTPUT   = 3'd4;

    reg [2:0]  state;
    reg [3:0]  mac_idx;
    reg signed [47:0] accumulator;

    // Pre-add values (symmetric: x[k] + x[TAPS-1-k])
    wire signed [24:0] pre_add = {delay_line[mac_idx][23], delay_line[mac_idx]} + 
                                  {delay_line[TAPS-1-mac_idx][23], delay_line[TAPS-1-mac_idx]};

    always @(posedge clk) begin
        if (rst) begin
            state       <= ST_IDLE;
            mac_idx     <= 4'd0;
            accumulator <= 48'd0;
            audio_out   <= 24'd0;
            ready       <= 1'b0;
            for (i = 0; i < TAPS; i = i + 1)
                delay_line[i] <= 24'd0;
        end else begin
            ready <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (sample_clk) begin
                        state <= ST_SHIFT;
                    end
                end

                ST_SHIFT: begin
                    // Shift new sample into delay line
                    for (i = TAPS-1; i > 0; i = i - 1)
                        delay_line[i] <= delay_line[i-1];
                    delay_line[0] <= audio_in;
                    accumulator   <= 48'd0;
                    mac_idx       <= 4'd0;
                    state         <= ST_MAC;
                end

                ST_MAC: begin
                    // Multiply pre-added pair by coefficient
                    accumulator <= accumulator + ($signed(coeff[mac_idx]) * pre_add);
                    if (mac_idx == HALF - 1) begin
                        state <= ST_CENTER;
                    end else begin
                        mac_idx <= mac_idx + 1'b1;
                    end
                end

                ST_CENTER: begin
                    // Add center tap (no pre-add needed)
                    accumulator <= accumulator + ($signed(coeff[HALF]) * 
                                   {{1{delay_line[HALF][23]}}, delay_line[HALF]});
                    state <= ST_OUTPUT;
                end

                ST_OUTPUT: begin
                    // Scale output (shift right by coefficient fractional bits)
                    // and saturate
                    begin
                        reg signed [47:0] scaled;
                        scaled = accumulator >>> 14;
                        if (scaled > $signed(48'sh00000000_3FFFFF))
                            audio_out <= `AUDIO_MAX;
                        else if (scaled < $signed(48'shFFFFFFFF_C00000))
                            audio_out <= `AUDIO_MIN;
                        else
                            audio_out <= scaled[23:0];
                    end
                    ready <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
