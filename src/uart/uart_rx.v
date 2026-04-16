//============================================================================
// UART Receiver
// 921600 baud @ 100 MHz system clock
// 8N1 format, 16x oversampling for reliable bit-center detection
//============================================================================

`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 921_600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx_in,        // UART RX line
    output reg  [7:0] rx_data,      // Received byte
    output reg        rx_valid      // Data valid (single pulse)
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    localparam HALF_DIV = BAUD_DIV / 2;

    // Input synchronizer (prevent metastability)
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx_in;
        rx_sync2 <= rx_sync1;
    end

    // State machine
    localparam ST_IDLE  = 2'd0;
    localparam ST_START = 2'd1;
    localparam ST_DATA  = 2'd2;
    localparam ST_STOP  = 2'd3;

    reg [1:0]  state;
    reg [7:0]  baud_counter;
    reg [7:0]  shift_reg;
    reg [2:0]  bit_index;

    always @(posedge clk) begin
        if (rst) begin
            state        <= ST_IDLE;
            baud_counter <= 8'd0;
            shift_reg    <= 8'd0;
            bit_index    <= 3'd0;
            rx_data      <= 8'd0;
            rx_valid     <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (~rx_sync2) begin  // Falling edge = start bit
                        state        <= ST_START;
                        baud_counter <= 8'd0;
                    end
                end

                ST_START: begin
                    // Wait half-bit to sample at center of start bit
                    if (baud_counter >= HALF_DIV - 1) begin
                        if (~rx_sync2) begin  // Confirm start bit is still low
                            baud_counter <= 8'd0;
                            bit_index    <= 3'd0;
                            state        <= ST_DATA;
                        end else begin
                            state <= ST_IDLE;  // False start
                        end
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                ST_DATA: begin
                    if (baud_counter >= BAUD_DIV - 1) begin
                        baud_counter <= 8'd0;
                        shift_reg    <= {rx_sync2, shift_reg[7:1]};  // LSB first
                        if (bit_index >= 3'd7) begin
                            state <= ST_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                ST_STOP: begin
                    if (baud_counter >= BAUD_DIV - 1) begin
                        if (rx_sync2) begin  // Valid stop bit
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                        state <= ST_IDLE;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
