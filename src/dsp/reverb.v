//============================================================================
// Schroeder Reverberator
// Classic algorithmic reverb using 4 parallel comb filters and
// 2 series all-pass filters.
// Comb filter delays are mutually prime to avoid metallic resonances.
// All-pass filters add echo density without changing frequency response.
//
// Total BRAM usage: ~16 KB (well within Artix-7 capacity)
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module reverb (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire               bypass,        // Bypass effect
    input  wire signed [23:0] audio_in,      // Q1.23 input
    input  wire [7:0]         decay,         // Reverb decay time (0=short, 255=long)
    input  wire [7:0]         mix,           // Dry/Wet mix
    output reg  signed [23:0] audio_out,     // Q1.23 output
    output wire               ready
);

    assign ready = 1'b1;

    //------------------------------------------------------------------------
    // Comb Filter Delays (mutually prime for diffuse reverb)
    //------------------------------------------------------------------------
    localparam COMB1_LEN = 1687;
    localparam COMB2_LEN = 1601;
    localparam COMB3_LEN = 2053;
    localparam COMB4_LEN = 2251;

    // All-pass filter delays
    localparam AP1_LEN = 347;
    localparam AP2_LEN = 113;

    //------------------------------------------------------------------------
    // Feedback gain from decay parameter
    // g = 0.5 + decay * 0.45/255 → range 0.5 to 0.95
    // In Q1.15: 16384 to 31130
    //------------------------------------------------------------------------
    wire [15:0] fb_gain = 16'd16384 + ({8'd0, decay} * 16'd58); // ≈0.5 + decay*0.45/255
    localparam GAIN_SHIFT = 15;

    //========================================================================
    // COMB FILTER 1
    //========================================================================
    (* ram_style = "block" *)
    reg signed [23:0] comb1_buf [0:COMB1_LEN-1];
    reg [10:0] comb1_ptr;
    reg signed [23:0] comb1_out;

    always @(posedge clk) begin
        if (rst) begin
            comb1_ptr <= 0;
            comb1_out <= 24'd0;
        end else if (sample_clk) begin
            comb1_out <= comb1_buf[comb1_ptr];
            // feedback: write input + gain * delayed output
            begin : comb1_write
                reg signed [39:0] fb1;
                reg signed [24:0] sum1;
                fb1 = $signed(comb1_out) * $signed({1'b0, fb_gain});
                sum1 = {audio_in[23], audio_in} + {fb1[39], fb1[39:16]};
                // Saturate and write
                if (sum1 > $signed(25'sh3FFFFF))
                    comb1_buf[comb1_ptr] <= `AUDIO_MAX;
                else if (sum1 < $signed(25'shC00000))
                    comb1_buf[comb1_ptr] <= `AUDIO_MIN;
                else
                    comb1_buf[comb1_ptr] <= sum1[23:0];
            end
            comb1_ptr <= (comb1_ptr >= COMB1_LEN-1) ? 0 : comb1_ptr + 1'b1;
        end
    end

    //========================================================================
    // COMB FILTER 2
    //========================================================================
    (* ram_style = "block" *)
    reg signed [23:0] comb2_buf [0:COMB2_LEN-1];
    reg [10:0] comb2_ptr;
    reg signed [23:0] comb2_out;

    always @(posedge clk) begin
        if (rst) begin
            comb2_ptr <= 0;
            comb2_out <= 24'd0;
        end else if (sample_clk) begin
            comb2_out <= comb2_buf[comb2_ptr];
            begin : comb2_write
                reg signed [39:0] fb2;
                reg signed [24:0] sum2;
                fb2 = $signed(comb2_out) * $signed({1'b0, fb_gain});
                sum2 = {audio_in[23], audio_in} + {fb2[39], fb2[39:16]};
                if (sum2 > $signed(25'sh3FFFFF))
                    comb2_buf[comb2_ptr] <= `AUDIO_MAX;
                else if (sum2 < $signed(25'shC00000))
                    comb2_buf[comb2_ptr] <= `AUDIO_MIN;
                else
                    comb2_buf[comb2_ptr] <= sum2[23:0];
            end
            comb2_ptr <= (comb2_ptr >= COMB2_LEN-1) ? 0 : comb2_ptr + 1'b1;
        end
    end

    //========================================================================
    // COMB FILTER 3
    //========================================================================
    (* ram_style = "block" *)
    reg signed [23:0] comb3_buf [0:COMB3_LEN-1];
    reg [11:0] comb3_ptr;
    reg signed [23:0] comb3_out;

    always @(posedge clk) begin
        if (rst) begin
            comb3_ptr <= 0;
            comb3_out <= 24'd0;
        end else if (sample_clk) begin
            comb3_out <= comb3_buf[comb3_ptr];
            begin : comb3_write
                reg signed [39:0] fb3;
                reg signed [24:0] sum3;
                fb3 = $signed(comb3_out) * $signed({1'b0, fb_gain});
                sum3 = {audio_in[23], audio_in} + {fb3[39], fb3[39:16]};
                if (sum3 > $signed(25'sh3FFFFF))
                    comb3_buf[comb3_ptr] <= `AUDIO_MAX;
                else if (sum3 < $signed(25'shC00000))
                    comb3_buf[comb3_ptr] <= `AUDIO_MIN;
                else
                    comb3_buf[comb3_ptr] <= sum3[23:0];
            end
            comb3_ptr <= (comb3_ptr >= COMB3_LEN-1) ? 0 : comb3_ptr + 1'b1;
        end
    end

    //========================================================================
    // COMB FILTER 4
    //========================================================================
    (* ram_style = "block" *)
    reg signed [23:0] comb4_buf [0:COMB4_LEN-1];
    reg [11:0] comb4_ptr;
    reg signed [23:0] comb4_out;

    always @(posedge clk) begin
        if (rst) begin
            comb4_ptr <= 0;
            comb4_out <= 24'd0;
        end else if (sample_clk) begin
            comb4_out <= comb4_buf[comb4_ptr];
            begin : comb4_write
                reg signed [39:0] fb4;
                reg signed [24:0] sum4;
                fb4 = $signed(comb4_out) * $signed({1'b0, fb_gain});
                sum4 = {audio_in[23], audio_in} + {fb4[39], fb4[39:16]};
                if (sum4 > $signed(25'sh3FFFFF))
                    comb4_buf[comb4_ptr] <= `AUDIO_MAX;
                else if (sum4 < $signed(25'shC00000))
                    comb4_buf[comb4_ptr] <= `AUDIO_MIN;
                else
                    comb4_buf[comb4_ptr] <= sum4[23:0];
            end
            comb4_ptr <= (comb4_ptr >= COMB4_LEN-1) ? 0 : comb4_ptr + 1'b1;
        end
    end

    //========================================================================
    // Sum Comb Filters (÷4 to prevent overflow)
    //========================================================================
    wire signed [25:0] comb_sum = {comb1_out[23], comb1_out[23], comb1_out} +
                                  {comb2_out[23], comb2_out[23], comb2_out} +
                                  {comb3_out[23], comb3_out[23], comb3_out} +
                                  {comb4_out[23], comb4_out[23], comb4_out};
    wire signed [23:0] comb_mixed = comb_sum[25:2]; // Divide by 4

    //========================================================================
    // ALL-PASS FILTER 1
    // y[n] = -g*x[n] + x[n-D] + g*y[n-D]
    //========================================================================
    localparam signed [15:0] AP_GAIN = 16'sd11469; // 0.7 in Q1.15
    
    (* ram_style = "block" *)
    reg signed [23:0] ap1_buf [0:AP1_LEN-1];
    reg [8:0] ap1_ptr;
    reg signed [23:0] ap1_out;
    reg signed [23:0] ap1_delayed;

    always @(posedge clk) begin
        if (rst) begin
            ap1_ptr <= 0;
            ap1_out <= 24'd0;
        end else if (sample_clk) begin
            ap1_delayed <= ap1_buf[ap1_ptr];
            begin : ap1_calc
                reg signed [39:0] gx, gy;
                reg signed [24:0] out_full;
                gx = $signed(AP_GAIN) * $signed(comb_mixed);
                gy = $signed(AP_GAIN) * $signed(ap1_delayed);
                out_full = -{gx[39], gx[39:16]} + {ap1_delayed[23], ap1_delayed} + 
                           {gy[39], gy[39:16]};
                if (out_full > $signed(25'sh3FFFFF))
                    ap1_out <= `AUDIO_MAX;
                else if (out_full < $signed(25'shC00000))
                    ap1_out <= `AUDIO_MIN;
                else
                    ap1_out <= out_full[23:0];
            end
            ap1_buf[ap1_ptr] <= comb_mixed;
            ap1_ptr <= (ap1_ptr >= AP1_LEN-1) ? 0 : ap1_ptr + 1'b1;
        end
    end

    //========================================================================
    // ALL-PASS FILTER 2
    //========================================================================
    (* ram_style = "block" *)
    reg signed [23:0] ap2_buf [0:AP2_LEN-1];
    reg [6:0] ap2_ptr;
    reg signed [23:0] ap2_out;
    reg signed [23:0] ap2_delayed;

    always @(posedge clk) begin
        if (rst) begin
            ap2_ptr <= 0;
            ap2_out <= 24'd0;
        end else if (sample_clk) begin
            ap2_delayed <= ap2_buf[ap2_ptr];
            begin : ap2_calc
                reg signed [39:0] gx2, gy2;
                reg signed [24:0] out_full2;
                gx2 = $signed(AP_GAIN) * $signed(ap1_out);
                gy2 = $signed(AP_GAIN) * $signed(ap2_delayed);
                out_full2 = -{gx2[39], gx2[39:16]} + {ap2_delayed[23], ap2_delayed} + 
                            {gy2[39], gy2[39:16]};
                if (out_full2 > $signed(25'sh3FFFFF))
                    ap2_out <= `AUDIO_MAX;
                else if (out_full2 < $signed(25'shC00000))
                    ap2_out <= `AUDIO_MIN;
                else
                    ap2_out <= out_full2[23:0];
            end
            ap2_buf[ap2_ptr] <= ap1_out;
            ap2_ptr <= (ap2_ptr >= AP2_LEN-1) ? 0 : ap2_ptr + 1'b1;
        end
    end

    //========================================================================
    // Dry/Wet Mix
    //========================================================================
    wire signed [31:0] wet_part = $signed(ap2_out) * $signed({1'b0, mix});
    wire signed [31:0] dry_part = $signed(audio_in) * $signed({1'b0, ~mix});
    wire signed [31:0] mixed = (wet_part + dry_part) >>> 8;

    wire signed [23:0] mixed_sat;
    assign mixed_sat = (mixed > $signed(32'sh003FFFFF)) ? `AUDIO_MAX :
                       (mixed < $signed(32'shFFC00000)) ? `AUDIO_MIN :
                       mixed[23:0];

    always @(posedge clk) begin
        if (rst) begin
            audio_out <= 24'd0;
        end else if (sample_clk) begin
            audio_out <= bypass ? audio_in : mixed_sat;
        end
    end

    // Initialize buffers (simulation)
    integer i;
    initial begin
        for (i = 0; i < COMB1_LEN; i = i+1) comb1_buf[i] = 24'd0;
        for (i = 0; i < COMB2_LEN; i = i+1) comb2_buf[i] = 24'd0;
        for (i = 0; i < COMB3_LEN; i = i+1) comb3_buf[i] = 24'd0;
        for (i = 0; i < COMB4_LEN; i = i+1) comb4_buf[i] = 24'd0;
        for (i = 0; i < AP1_LEN; i = i+1) ap1_buf[i] = 24'd0;
        for (i = 0; i < AP2_LEN; i = i+1) ap2_buf[i] = 24'd0;
    end

endmodule
