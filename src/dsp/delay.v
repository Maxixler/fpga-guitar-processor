//============================================================================
// Digital Delay Effect
// BRAM-based circular buffer delay with feedback and low-pass filter
// in the feedback loop for natural-sounding echo decay.
//
// Max delay: 65536 samples @ 48kHz = ~1.36 seconds
// Features: adjustable delay time, feedback, dry/wet mix
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module delay (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_clk,    // 48 kHz strobe
    input  wire               bypass,        // Bypass effect
    input  wire signed [23:0] audio_in,      // Q1.23 input
    input  wire [7:0]         delay_time,    // Delay time (0=short, 255=~1.36s)
    input  wire [7:0]         feedback,      // Feedback amount (0=none, 230=max ~90%)
    input  wire [7:0]         mix,           // Dry/Wet mix
    output reg  signed [23:0] audio_out,     // Q1.23 output
    output wire               ready
);

    assign ready = 1'b1;

    //------------------------------------------------------------------------
    // BRAM Delay Buffer (64K samples × 24 bits)
    //------------------------------------------------------------------------
    localparam BUFFER_DEPTH = 65536;
    localparam ADDR_WIDTH   = 16;

    // Infer Block RAM
    (* ram_style = "block" *)
    reg signed [23:0] delay_buffer [0:BUFFER_DEPTH-1];

    reg [ADDR_WIDTH-1:0] write_addr;
    reg [ADDR_WIDTH-1:0] read_addr;
    reg signed [23:0]    read_data;

    // Delay length from parameter: delay_time * 256 (0 to 65280 samples)
    wire [ADDR_WIDTH-1:0] delay_length = {delay_time, 8'd0};

    //------------------------------------------------------------------------
    // Read/Write Logic
    //------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            write_addr <= 0;
        end else if (sample_clk) begin
            write_addr <= write_addr + 1'b1;
        end
    end

    // Read address = write - delay_length (wraps naturally)
    always @(*) begin
        read_addr = write_addr - delay_length;
    end

    // BRAM read (synchronous)
    always @(posedge clk) begin
        read_data <= delay_buffer[read_addr];
    end

    //------------------------------------------------------------------------
    // Feedback Path with Low-Pass Filter
    // LP filter in feedback softens the echoes over time (more natural)
    // Simple 1st order: y = 0.7*x + 0.3*y_prev
    //------------------------------------------------------------------------
    reg signed [23:0] fb_filtered;
    reg signed [23:0] fb_prev;

    wire signed [31:0] fb_new = ($signed(read_data) * $signed(16'sd11469)) +  // 0.7 * 16384
                                ($signed(fb_prev)   * $signed(16'sd4915));     // 0.3 * 16384
    wire signed [23:0] fb_lp = fb_new[37:14]; // Divide by 16384

    always @(posedge clk) begin
        if (rst) begin
            fb_filtered <= 24'd0;
            fb_prev     <= 24'd0;
        end else if (sample_clk) begin
            fb_filtered <= fb_lp;
            fb_prev     <= fb_lp;
        end
    end

    //------------------------------------------------------------------------
    // Feedback Scaling
    // Max feedback = 230/256 ≈ 90% (prevents runaway oscillation)
    //------------------------------------------------------------------------
    wire [7:0] fb_clamped = (feedback > 8'd230) ? 8'd230 : feedback;
    wire signed [31:0] fb_scaled = $signed(fb_filtered) * $signed({1'b0, fb_clamped});
    wire signed [23:0] fb_amount = fb_scaled[31:8];

    //------------------------------------------------------------------------
    // Mix input with feedback and write to buffer
    //------------------------------------------------------------------------
    wire signed [24:0] write_sum = {audio_in[23], audio_in} + {fb_amount[23], fb_amount};
    wire signed [23:0] write_data;
    assign write_data = (write_sum > $signed(25'sh3FFFFF)) ? `AUDIO_MAX :
                        (write_sum < $signed(25'shC00000)) ? `AUDIO_MIN :
                        write_sum[23:0];

    // BRAM write
    always @(posedge clk) begin
        if (sample_clk) begin
            delay_buffer[write_addr] <= write_data;
        end
    end

    //------------------------------------------------------------------------
    // Dry/Wet Mix Output
    //------------------------------------------------------------------------
    wire signed [31:0] wet_part = $signed(read_data) * $signed({1'b0, mix});
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

    // Initialize buffer to zero (simulation only)
    integer i;
    initial begin
        for (i = 0; i < BUFFER_DEPTH; i = i + 1)
            delay_buffer[i] = 24'd0;
    end

endmodule
