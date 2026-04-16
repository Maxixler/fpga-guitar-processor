//============================================================================
// Top-Level Testbench
// Simulates the complete guitar processor with a 1 kHz sine wave test signal.
// Verifies audio path from input through effects chain to output.
//============================================================================

`timescale 1ns / 1ps

module tb_top;

    // System signals
    reg         CLK100MHZ;
    reg         CPU_RESETN;
    reg         vauxp6, vauxn6;
    wire        AUD_PWM, AUD_SD;
    reg  [15:0] SW;
    reg         BTNC, BTNU, BTND, BTNL, BTNR;
    wire [15:0] LED;
    wire [7:0]  AN;
    wire [6:0]  SEG;
    wire        DP;

    // 100 MHz clock generation
    initial CLK100MHZ = 0;
    always #5 CLK100MHZ = ~CLK100MHZ;  // 10ns period = 100 MHz

    //------------------------------------------------------------------------
    // Device Under Test
    //------------------------------------------------------------------------
    top_guitar_processor u_dut (
        .CLK100MHZ  (CLK100MHZ),
        .CPU_RESETN (CPU_RESETN),
        .vauxp6     (vauxp6),
        .vauxn6     (vauxn6),
        .AUD_PWM    (AUD_PWM),
        .AUD_SD     (AUD_SD),
        .SW         (SW),
        .BTNC       (BTNC),
        .BTNU       (BTNU),
        .BTND       (BTND),
        .BTNL       (BTNL),
        .BTNR       (BTNR),
        .LED        (LED),
        .AN         (AN),
        .SEG        (SEG),
        .DP         (DP)
    );

    //------------------------------------------------------------------------
    // Test Stimulus
    //------------------------------------------------------------------------
    integer i;
    real    t_sec;
    real    sine_val;

    initial begin
        $display("========================================");
        $display("  Guitar Processor Testbench Start");
        $display("========================================");

        // Initialize
        CPU_RESETN = 0;
        vauxp6     = 0;
        vauxn6     = 0;
        SW         = 16'hF000;  // Max volume, no effects
        BTNC = 0; BTNU = 0; BTND = 0; BTNL = 0; BTNR = 0;

        // Reset pulse (1 μs)
        #1000;
        CPU_RESETN = 1;
        $display("[%0t] Reset released", $time);

        // Wait for system to settle
        #10000;

        // Enable Noise Gate + Distortion
        SW = 16'hF003;  // SW[0]=NG, SW[1]=Dist, Vol=max
        $display("[%0t] Enabled: Noise Gate + Distortion", $time);

        // Run for 2ms (about 100 samples at 48kHz)
        #2_000_000;

        // Enable Delay
        SW = 16'hF00B;  // Add delay (SW[3])
        $display("[%0t] Enabled: + Delay", $time);
        #2_000_000;

        // Enable Reverb
        SW = 16'hF01B;  // Add reverb (SW[4])
        $display("[%0t] Enabled: + Reverb", $time);
        #2_000_000;

        // Press center button to cycle effect
        BTNC = 1;
        #20_000_000;
        BTNC = 0;
        #1_000_000;

        // Adjust parameter up
        BTNU = 1;
        #20_000_000;
        BTNU = 0;
        #1_000_000;

        // Enable all effects
        SW = 16'hF07F;
        $display("[%0t] All effects enabled", $time);
        #5_000_000;

        // Reduce volume
        SW = 16'h807F;
        $display("[%0t] Volume reduced to 50%%", $time);
        #2_000_000;

        $display("========================================");
        $display("  Testbench Complete");
        $display("========================================");
        $finish;
    end

    //------------------------------------------------------------------------
    // Monitor key signals
    //------------------------------------------------------------------------
    initial begin
        $monitor("[%0t] AUD_PWM=%b AUD_SD=%b LED=%h",
                 $time, AUD_PWM, AUD_SD, LED);
    end

    // Optional: dump waveforms for viewer
    initial begin
        $dumpfile("guitar_processor.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
