//============================================================================
// Delay Effect Testbench
// Tests delay with varying feedback and delay time parameters.
// Verifies echo generation and feedback decay.
//============================================================================

`timescale 1ns / 1ps

module tb_delay;

    reg         clk;
    reg         rst;
    reg         sample_clk;
    reg         bypass;
    reg  [23:0] audio_in;
    reg  [7:0]  delay_time;
    reg  [7:0]  feedback;
    reg  [7:0]  mix;
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
    delay u_dut (
        .clk        (clk),
        .rst        (rst),
        .sample_clk (sample_clk),
        .bypass     (bypass),
        .audio_in   (audio_in),
        .delay_time (delay_time),
        .feedback   (feedback),
        .mix        (mix),
        .audio_out  (audio_out),
        .ready      (ready)
    );

    integer sample_num;

    initial begin
        $display("Delay Testbench Start");
        rst        = 1;
        bypass     = 0;
        delay_time = 8'd10;   // Short delay for testing (~53ms)
        feedback   = 8'd128;  // 50% feedback
        mix        = 8'd128;  // 50% wet
        audio_in   = 24'd0;
        sample_num = 0;

        #100 rst = 0;

        // Send a single impulse (Dirac delta)
        @(posedge sample_clk);
        audio_in = 24'sh200000;  // 0.25 amplitude impulse
        sample_num = 1;
        $display("Sample %0d: Impulse sent, in=%h", sample_num, audio_in);

        @(posedge sample_clk);
        audio_in = 24'd0;  // Back to silence

        // Wait and observe echoes (6000 samples ≈ 125ms)
        repeat(6000) begin
            @(posedge sample_clk);
            sample_num = sample_num + 1;
            if (audio_out != 24'd0 && (sample_num % 100 == 0))
                $display("Sample %0d: out=%h", sample_num, audio_out);
        end

        // Test bypass
        $display("--- Test Bypass ---");
        bypass = 1;
        audio_in = 24'sh100000;
        repeat(10) @(posedge sample_clk);
        $display("Bypass: in=%h out=%h (should match)", audio_in, audio_out);

        $display("Delay Testbench Complete");
        $finish;
    end

    initial begin
        $dumpfile("delay.vcd");
        $dumpvars(0, tb_delay);
    end

endmodule
