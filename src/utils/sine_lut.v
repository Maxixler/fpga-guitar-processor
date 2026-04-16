//============================================================================
// Sine Wave Lookup Table
// 256 entries, 16-bit signed output (-32767 to +32767)
// Full cycle: address 0..255 = 0° .. 360°
// Uses quarter-wave symmetry to save resources
//============================================================================

`timescale 1ns / 1ps

module sine_lut (
    input  wire        clk,
    input  wire [7:0]  phase,       // 8-bit phase (0-255 = 0°-360°)
    output reg  [15:0] sine_out     // 16-bit signed sine value
);

    // Quarter-wave table (64 entries, positive half of first quadrant)
    reg [15:0] quarter_table [0:63];

    // Quadrant decode
    wire [1:0] quadrant = phase[7:6];
    wire [5:0] index    = phase[5:0];

    // Mirror index for quadrants 2 and 4
    wire [5:0] lut_addr = (quadrant[0]) ? (6'd63 - index) : index;

    reg [15:0] lut_value;

    // Initialize quarter-wave sine table
    // Values: round(32767 * sin(pi/2 * i/64)) for i = 0..63
    initial begin
        quarter_table[ 0] = 16'h0000;  quarter_table[ 1] = 16'h0324;
        quarter_table[ 2] = 16'h0648;  quarter_table[ 3] = 16'h096A;
        quarter_table[ 4] = 16'h0C8C;  quarter_table[ 5] = 16'h0FAB;
        quarter_table[ 6] = 16'h12C8;  quarter_table[ 7] = 16'h15E2;
        quarter_table[ 8] = 16'h18F9;  quarter_table[ 9] = 16'h1C0B;
        quarter_table[10] = 16'h1F1A;  quarter_table[11] = 16'h2223;
        quarter_table[12] = 16'h2528;  quarter_table[13] = 16'h2827;
        quarter_table[14] = 16'h2B1F;  quarter_table[15] = 16'h2E11;
        quarter_table[16] = 16'h30FB;  quarter_table[17] = 16'h33DF;
        quarter_table[18] = 16'h36BA;  quarter_table[19] = 16'h398C;
        quarter_table[20] = 16'h3C56;  quarter_table[21] = 16'h3F17;
        quarter_table[22] = 16'h41CE;  quarter_table[23] = 16'h447A;
        quarter_table[24] = 16'h471C;  quarter_table[25] = 16'h49B4;
        quarter_table[26] = 16'h4C3F;  quarter_table[27] = 16'h4EBF;
        quarter_table[28] = 16'h5133;  quarter_table[29] = 16'h539B;
        quarter_table[30] = 16'h55F5;  quarter_table[31] = 16'h5842;
        quarter_table[32] = 16'h5A82;  quarter_table[33] = 16'h5CB4;
        quarter_table[34] = 16'h5ED7;  quarter_table[35] = 16'h60EC;
        quarter_table[36] = 16'h62F2;  quarter_table[37] = 16'h64E8;
        quarter_table[38] = 16'h66CF;  quarter_table[39] = 16'h68A6;
        quarter_table[40] = 16'h6A6D;  quarter_table[41] = 16'h6C24;
        quarter_table[42] = 16'h6DC9;  quarter_table[43] = 16'h6F5F;
        quarter_table[44] = 16'h70E2;  quarter_table[45] = 16'h7254;
        quarter_table[46] = 16'h73B5;  quarter_table[47] = 16'h7504;
        quarter_table[48] = 16'h7641;  quarter_table[49] = 16'h776C;
        quarter_table[50] = 16'h7884;  quarter_table[51] = 16'h798A;
        quarter_table[52] = 16'h7A7D;  quarter_table[53] = 16'h7B5D;
        quarter_table[54] = 16'h7C29;  quarter_table[55] = 16'h7CE3;
        quarter_table[56] = 16'h7D8A;  quarter_table[57] = 16'h7E1D;
        quarter_table[58] = 16'h7E9D;  quarter_table[59] = 16'h7F09;
        quarter_table[60] = 16'h7F62;  quarter_table[61] = 16'h7FA7;
        quarter_table[62] = 16'h7FD8;  quarter_table[63] = 16'h7FF6;
    end

    always @(posedge clk) begin
        lut_value <= quarter_table[lut_addr];
    end

    // Apply sign based on quadrant (negative for quadrants 2,3 i.e. phase[7]=1)
    always @(posedge clk) begin
        if (quadrant[1])
            sine_out <= ~lut_value + 1'b1;  // Negate for upper half
        else
            sine_out <= lut_value;
    end

endmodule
