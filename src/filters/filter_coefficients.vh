//============================================================================
// Filter Coefficients Header
// All coefficients in Q2.14 fixed-point format (16-bit signed)
// Used by FIR and Biquad filter modules
//============================================================================

`ifndef FILTER_COEFFICIENTS_VH
`define FILTER_COEFFICIENTS_VH

// ===== FIR Low-Pass Filter Coefficients =====
// 31-tap FIR, Hamming window, fc = 20 kHz @ fs = 48 kHz
// Normalized cutoff = 20000/24000 = 0.833
// Coefficients scaled to Q2.14 (multiply by 16384)

// Since the cutoff is very close to Nyquist, this is a mild anti-aliasing filter
// Mostly removing content above 20 kHz

`define FIR_TAPS 31

// ===== Biquad (IIR) Filter Coefficients =====
// General biquad: H(z) = (b0 + b1·z^-1 + b2·z^-2) / (1 + a1·z^-1 + a2·z^-2)
// Coefficients in Q2.14 format

// Low-pass biquad, fc = 4 kHz @ 48 kHz (for tone control)
`define BIQUAD_LP_B0  16'sd1645    // 0.1004 × 16384
`define BIQUAD_LP_B1  16'sd3290    // 0.2008 × 16384
`define BIQUAD_LP_B2  16'sd1645    // 0.1004 × 16384
`define BIQUAD_LP_A1  -16'sd16088  // -0.9817 × 16384
`define BIQUAD_LP_A2  16'sd6283    // 0.3834 × 16384

// Low-pass biquad, fc = 8 kHz @ 48 kHz (for delay feedback)
`define BIQUAD_LP8K_B0  16'sd4277   // 0.2610 × 16384
`define BIQUAD_LP8K_B1  16'sd8554   // 0.5221 × 16384
`define BIQUAD_LP8K_B2  16'sd4277   // 0.2610 × 16384
`define BIQUAD_LP8K_A1  -16'sd5765  // -0.3518 × 16384
`define BIQUAD_LP8K_A2  16'sd1490   // 0.0910 × 16384

`endif // FILTER_COEFFICIENTS_VH
