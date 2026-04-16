//============================================================================
// VU Meter — LED Volume Level Indicator
// Converts audio amplitude to 8-LED bar graph display.
// Uses peak-hold with decay for readable level indication.
// LED[15:8] = Input level, LED[7:0] = Output level
//============================================================================

`timescale 1ns / 1ps

module vu_meter (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_clk,      // 48 kHz strobe
    input  wire [23:0] level_in,        // Absolute input level
    input  wire [23:0] level_out,       // Absolute output level
    output reg  [15:0] led_out          // LED[15:8]=in, LED[7:0]=out
);

    //------------------------------------------------------------------------
    // Peak Hold with Decay
    // Holds peak for ~100ms, then decays slowly
    //------------------------------------------------------------------------
    reg [23:0] peak_in, peak_out;
    reg [11:0] decay_counter_in, decay_counter_out;

    localparam HOLD_TIME = 12'd4800;   // 100ms @ 48kHz
    localparam DECAY_RATE = 24'd16384; // Decay per sample after hold

    always @(posedge clk) begin
        if (rst) begin
            peak_in  <= 24'd0;
            peak_out <= 24'd0;
            decay_counter_in  <= 12'd0;
            decay_counter_out <= 12'd0;
        end else if (sample_clk) begin
            // Input peak
            if (level_in > peak_in) begin
                peak_in <= level_in;
                decay_counter_in <= 12'd0;
            end else if (decay_counter_in < HOLD_TIME) begin
                decay_counter_in <= decay_counter_in + 1'b1;
            end else begin
                peak_in <= (peak_in > DECAY_RATE) ? peak_in - DECAY_RATE : 24'd0;
            end

            // Output peak
            if (level_out > peak_out) begin
                peak_out <= level_out;
                decay_counter_out <= 12'd0;
            end else if (decay_counter_out < HOLD_TIME) begin
                decay_counter_out <= decay_counter_out + 1'b1;
            end else begin
                peak_out <= (peak_out > DECAY_RATE) ? peak_out - DECAY_RATE : 24'd0;
            end
        end
    end

    //------------------------------------------------------------------------
    // Level to 8-LED bar conversion
    // Logarithmic-ish scaling for better visual response
    //------------------------------------------------------------------------
    function [7:0] level_to_leds;
        input [23:0] level;
        begin
            if      (level > 24'h380000) level_to_leds = 8'b11111111;  // -0.6 dB
            else if (level > 24'h300000) level_to_leds = 8'b01111111;  // -2.5 dB
            else if (level > 24'h280000) level_to_leds = 8'b00111111;  // -4.1 dB
            else if (level > 24'h200000) level_to_leds = 8'b00011111;  // -6.0 dB
            else if (level > 24'h180000) level_to_leds = 8'b00001111;  // -8.5 dB
            else if (level > 24'h100000) level_to_leds = 8'b00000111;  // -12.0 dB
            else if (level > 24'h080000) level_to_leds = 8'b00000011;  // -18.0 dB
            else if (level > 24'h020000) level_to_leds = 8'b00000001;  // -30.0 dB
            else                         level_to_leds = 8'b00000000;  // Below noise
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            led_out <= 16'd0;
        end else begin
            led_out[15:8] <= level_to_leds(peak_in);
            led_out[7:0]  <= level_to_leds(peak_out);
        end
    end

endmodule
