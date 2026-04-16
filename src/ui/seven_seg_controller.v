//============================================================================
// Seven-Segment Display Controller
// Drives 8-digit common-anode 7-segment display on Nexys A7.
// Shows effect name (left 4 digits) and parameter value (right 4 digits).
// Uses time-multiplexing with ~1kHz refresh per digit.
//============================================================================

`timescale 1ns / 1ps

module seven_seg_controller (
    input  wire        clk,           // 100 MHz
    input  wire        rst,
    input  wire [2:0]  active_effect, // Currently selected effect for display
    input  wire [7:0]  param_value,   // Parameter value to display
    input  wire [6:0]  effect_enables,// Which effects are active (for dots)
    output reg  [7:0]  AN,           // Anodes (active low)
    output reg  [6:0]  SEG,          // Segments a-g (active low)
    output reg         DP            // Decimal point (active low)
);

    //------------------------------------------------------------------------
    // Refresh counter: 100MHz / 100000 = 1kHz per digit, 125Hz total refresh
    //------------------------------------------------------------------------
    reg [16:0] refresh_counter;
    wire [2:0] digit_select;

    always @(posedge clk) begin
        if (rst)
            refresh_counter <= 17'd0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    assign digit_select = refresh_counter[16:14]; // 3-bit: 0-7

    //------------------------------------------------------------------------
    // Effect Name Encoding (4 characters per effect)
    // Using 7-segment displayable characters
    //------------------------------------------------------------------------
    // Effect names: GAtE, dISt, OUdr, dELy, rEUb, CHor, trEM
    // Each character encoded as 7-bit segment pattern (active low: gfedcba)

    reg [6:0] char_pattern;
    reg [6:0] name_chars [0:3];  // 4 characters for effect name

    // Character definitions (active low: segments gfedcba)
    localparam [6:0] CH_0 = 7'b1000000;  // 0
    localparam [6:0] CH_1 = 7'b1111001;  // 1
    localparam [6:0] CH_2 = 7'b0100100;  // 2
    localparam [6:0] CH_3 = 7'b0110000;  // 3
    localparam [6:0] CH_4 = 7'b0011001;  // 4
    localparam [6:0] CH_5 = 7'b0010010;  // 5
    localparam [6:0] CH_6 = 7'b0000010;  // 6
    localparam [6:0] CH_7 = 7'b1111000;  // 7
    localparam [6:0] CH_8 = 7'b0000000;  // 8
    localparam [6:0] CH_9 = 7'b0010000;  // 9
    localparam [6:0] CH_A = 7'b0001000;  // A
    localparam [6:0] CH_b = 7'b0000011;  // b
    localparam [6:0] CH_C = 7'b1000110;  // C
    localparam [6:0] CH_d = 7'b0100001;  // d
    localparam [6:0] CH_E = 7'b0000110;  // E
    localparam [6:0] CH_F = 7'b0001110;  // F
    localparam [6:0] CH_G = 7'b1000010;  // G
    localparam [6:0] CH_H = 7'b0001001;  // H
    localparam [6:0] CH_I = 7'b1111001;  // I (same as 1)
    localparam [6:0] CH_L = 7'b1000111;  // L
    localparam [6:0] CH_n = 7'b0101011;  // n
    localparam [6:0] CH_o = 7'b0100011;  // o
    localparam [6:0] CH_P = 7'b0001100;  // P
    localparam [6:0] CH_r = 7'b0101111;  // r
    localparam [6:0] CH_S = 7'b0010010;  // S (same as 5)
    localparam [6:0] CH_t = 7'b0000111;  // t
    localparam [6:0] CH_U = 7'b1000001;  // U
    localparam [6:0] CH_y = 7'b0010001;  // y
    localparam [6:0] CH_BLANK = 7'b1111111;

    // Select name characters based on active effect
    always @(*) begin
        case (active_effect)
            3'd0: begin // GAtE (Noise Gate)
                name_chars[0] = CH_G;
                name_chars[1] = CH_A;
                name_chars[2] = CH_t;
                name_chars[3] = CH_E;
            end
            3'd1: begin // dISt (Distortion)
                name_chars[0] = CH_d;
                name_chars[1] = CH_I;
                name_chars[2] = CH_S;
                name_chars[3] = CH_t;
            end
            3'd2: begin // OUdr (Overdrive)
                name_chars[0] = CH_o;
                name_chars[1] = CH_U;
                name_chars[2] = CH_d;
                name_chars[3] = CH_r;
            end
            3'd3: begin // dELy (Delay)
                name_chars[0] = CH_d;
                name_chars[1] = CH_E;
                name_chars[2] = CH_L;
                name_chars[3] = CH_y;
            end
            3'd4: begin // rEUb (Reverb)
                name_chars[0] = CH_r;
                name_chars[1] = CH_E;
                name_chars[2] = CH_U;
                name_chars[3] = CH_b;
            end
            3'd5: begin // CHor (Chorus)
                name_chars[0] = CH_C;
                name_chars[1] = CH_H;
                name_chars[2] = CH_o;
                name_chars[3] = CH_r;
            end
            3'd6: begin // trEM (Tremolo)
                name_chars[0] = CH_t;
                name_chars[1] = CH_r;
                name_chars[2] = CH_E;
                name_chars[3] = CH_n; // Using 'n' as closest to 'M'
            end
            default: begin
                name_chars[0] = CH_BLANK;
                name_chars[1] = CH_BLANK;
                name_chars[2] = CH_BLANK;
                name_chars[3] = CH_BLANK;
            end
        endcase
    end

    //------------------------------------------------------------------------
    // BCD conversion for parameter value (0-255)
    //------------------------------------------------------------------------
    reg [3:0] bcd_hundreds, bcd_tens, bcd_ones;

    always @(*) begin
        bcd_hundreds = param_value / 100;
        bcd_tens     = (param_value % 100) / 10;
        bcd_ones     = param_value % 10;
    end

    // BCD to 7-segment
    function [6:0] bcd_to_seg;
        input [3:0] bcd;
        case (bcd)
            4'd0: bcd_to_seg = CH_0;
            4'd1: bcd_to_seg = CH_1;
            4'd2: bcd_to_seg = CH_2;
            4'd3: bcd_to_seg = CH_3;
            4'd4: bcd_to_seg = CH_4;
            4'd5: bcd_to_seg = CH_5;
            4'd6: bcd_to_seg = CH_6;
            4'd7: bcd_to_seg = CH_7;
            4'd8: bcd_to_seg = CH_8;
            4'd9: bcd_to_seg = CH_9;
            default: bcd_to_seg = CH_BLANK;
        endcase
    endfunction

    //------------------------------------------------------------------------
    // Multiplexer: select digit and corresponding segment pattern
    //------------------------------------------------------------------------
    always @(*) begin
        AN  = 8'b11111111;  // All off by default
        SEG = CH_BLANK;
        DP  = 1'b1;         // Dot off by default

        case (digit_select)
            3'd7: begin AN = 8'b01111111; SEG = name_chars[0]; DP = effect_enables[active_effect] ? 1'b0 : 1'b1; end
            3'd6: begin AN = 8'b10111111; SEG = name_chars[1]; end
            3'd5: begin AN = 8'b11011111; SEG = name_chars[2]; end
            3'd4: begin AN = 8'b11101111; SEG = name_chars[3]; end
            3'd3: begin AN = 8'b11110111; SEG = CH_BLANK; end // Separator
            3'd2: begin AN = 8'b11111011; SEG = bcd_to_seg(bcd_hundreds); end
            3'd1: begin AN = 8'b11111101; SEG = bcd_to_seg(bcd_tens); end
            3'd0: begin AN = 8'b11111110; SEG = bcd_to_seg(bcd_ones); end
        endcase
    end

endmodule
