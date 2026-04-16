//============================================================================
// Fixed-Point Math Utilities
// Format: Q1.23 (1 sign bit, 23 fractional bits)
// Range: -1.0 to +0.9999998807907104
//============================================================================

`ifndef FIXED_POINT_MATH_VH
`define FIXED_POINT_MATH_VH

// Audio data parameters
`define AUDIO_WIDTH     24
`define FRAC_BITS       23
`define AUDIO_MAX       24'sh3FFFFF   // +0.999...
`define AUDIO_MIN       24'sh400000   // -1.0
`define AUDIO_ZERO      24'sh000000

// Extended precision for intermediate calculations
`define EXT_WIDTH       48
`define EXT_FRAC_BITS   46

// Common fixed-point constants (Q1.23)
`define FP_ONE          24'sh3FFFFF   // ~+1.0
`define FP_HALF         24'sh200000   // +0.5
`define FP_QUARTER      24'sh100000   // +0.25
`define FP_EIGHTH       24'sh080000   // +0.125
`define FP_NEG_ONE      24'sh400000   // -1.0
`define FP_ZERO         24'sh000000   // 0.0

// Saturation: clamp a wider value to 24-bit signed range
// Input: 48-bit signed, Output: 24-bit signed
`define SATURATE(x) \
    ((x) > $signed(48'sh00000000_3FFFFF)) ? `AUDIO_MAX : \
    ((x) < $signed(48'shFFFFFFFF_C00000)) ? `AUDIO_MIN : \
    (x)[`AUDIO_WIDTH-1:0]

// Saturate 32-bit to 24-bit
`define SATURATE32(x) \
    ((x) > $signed(32'sh003FFFFF)) ? `AUDIO_MAX : \
    ((x) < $signed(32'shFFC00000)) ? `AUDIO_MIN : \
    (x)[`AUDIO_WIDTH-1:0]

`endif // FIXED_POINT_MATH_VH
