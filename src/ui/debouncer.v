//============================================================================
// Button Debouncer
// Filters mechanical switch bounce using a counter-based approach.
// Also generates single-clock-cycle pulse on button press (edge detect).
// Debounce time: ~10ms @ 100 MHz (1M clock cycles)
//============================================================================

`timescale 1ns / 1ps

module debouncer (
    input  wire clk,          // 100 MHz
    input  wire rst,
    input  wire btn_in,       // Raw button input (active high)
    output reg  btn_out,      // Debounced level
    output reg  btn_pulse     // Single pulse on press (rising edge)
);

    localparam DEBOUNCE_COUNT = 20'd1_000_000;  // ~10ms @ 100MHz

    reg [19:0] counter;
    reg        btn_sync1, btn_sync2;  // 2-stage synchronizer
    reg        btn_prev;

    // Synchronize input to clock domain (prevent metastability)
    always @(posedge clk) begin
        if (rst) begin
            btn_sync1 <= 1'b0;
            btn_sync2 <= 1'b0;
        end else begin
            btn_sync1 <= btn_in;
            btn_sync2 <= btn_sync1;
        end
    end

    // Debounce counter
    always @(posedge clk) begin
        if (rst) begin
            counter  <= 20'd0;
            btn_out  <= 1'b0;
            btn_prev <= 1'b0;
            btn_pulse <= 1'b0;
        end else begin
            btn_pulse <= 1'b0;

            if (btn_sync2 != btn_out) begin
                // Input differs from current state — start counting
                if (counter >= DEBOUNCE_COUNT) begin
                    btn_out <= btn_sync2;
                    counter <= 20'd0;
                end else begin
                    counter <= counter + 1'b1;
                end
            end else begin
                counter <= 20'd0;
            end

            // Edge detection for pulse
            btn_prev <= btn_out;
            if (btn_out && !btn_prev)
                btn_pulse <= 1'b1;
        end
    end

endmodule
