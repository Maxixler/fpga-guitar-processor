//============================================================================
// Distortion Effect Testbench
// Tests softclip and hardclip modes with a 1kHz sine wave input.
// Outputs are logged for waveform analysis.
//============================================================================

`timescale 1ns / 1ps

module tb_distortion;

    reg         clk;
    reg         rst;
    reg         sample_clk;
    reg         bypass;
    reg  [23:0] audio_in;
    reg  [7:0]  gain;
    reg  [7:0]  tone;
    reg         clip_mode;
    wire [23:0] audio_out;
    wire        ready;

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // 48 kHz sample clock
    integer sample_cnt;
    initial sample_cnt = 0;
    always @(posedge clk) begin
        if (sample_cnt >= 2082) begin
            sample_cnt <= 0;
            sample_clk <= 1'b1;
        end else begin
            sample_cnt <= sample_cnt + 1;
            sample_clk <= 1'b0;
        end
    end

    // DUT
    distortion u_dut (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (bypass),
        .audio_in   (audio_in),
        .gain       (gain),
        .tone       (tone),
        .clip_mode  (clip_mode),
        .audio_out  (audio_out),
        .ready      (ready)
    );

    // 1kHz sine wave generation (48 samples per cycle at 48kHz)
    // Simplified: use a counter to index into sine values
    integer phase;
    real    sine_real;
    integer sine_int;

    initial begin
        $display("Distortion Testbench Start");
        rst       = 1;
        bypass    = 0;
        gain      = 8'd128;
        tone      = 8'd200;
        clip_mode = 0;  // Soft clip
        phase     = 0;
        audio_in  = 24'd0;

        #100 rst = 0;

        // Generate 100 samples of 1kHz sine
        repeat(100) begin
            @(posedge sample_clk);
            sine_real = $sin(2.0 * 3.14159265 * phase / 48.0);
            sine_int  = $rtoi(sine_real * 2097152.0);  // Scale to Q1.23 half range
            audio_in  = sine_int[23:0];
            phase     = phase + 1;
            $display("Sample %0d: in=%h out=%h", phase, audio_in, audio_out);
        end

        // Test hard clip mode
        $display("--- Switching to Hard Clip ---");
        clip_mode = 1;
        gain      = 8'd200;

        repeat(100) begin
            @(posedge sample_clk);
            sine_real = $sin(2.0 * 3.14159265 * phase / 48.0);
            sine_int  = $rtoi(sine_real * 2097152.0);
            audio_in  = sine_int[23:0];
            phase     = phase + 1;
            $display("Sample %0d: in=%h out=%h", phase, audio_in, audio_out);
        end

        // Test bypass
        $display("--- Bypass Mode ---");
        bypass = 1;
        repeat(48) begin
            @(posedge sample_clk);
            sine_real = $sin(2.0 * 3.14159265 * phase / 48.0);
            sine_int  = $rtoi(sine_real * 2097152.0);
            audio_in  = sine_int[23:0];
            phase     = phase + 1;
        end

        $display("Distortion Testbench Complete");
        $finish;
    end

    initial begin
        $dumpfile("distortion.vcd");
        $dumpvars(0, tb_distortion);
    end

endmodule
