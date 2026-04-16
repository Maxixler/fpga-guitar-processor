//============================================================================
// UART Transmitter
// 921600 baud @ 100 MHz system clock
// 8N1 format (8 data bits, no parity, 1 stop bit)
// FIFO-ready interface with valid/ready handshake
//============================================================================

`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 921_600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,      // Byte to transmit
    input  wire       tx_valid,     // Data valid (pulse)
    output reg        tx_ready,     // Ready to accept data
    output reg        tx_out        // UART TX line
);

    // Baud rate divider: 100MHz / 921600 = 108.5 ≈ 109
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

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
            tx_out       <= 1'b1;  // Idle high
            tx_ready     <= 1'b1;
        end else begin
            case (state)
                ST_IDLE: begin
                    tx_out   <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid) begin
                        shift_reg    <= tx_data;
                        state        <= ST_START;
                        baud_counter <= 8'd0;
                        tx_ready     <= 1'b0;
                    end
                end

                ST_START: begin
                    tx_out <= 1'b0;  // Start bit
                    if (baud_counter >= BAUD_DIV - 1) begin
                        baud_counter <= 8'd0;
                        bit_index    <= 3'd0;
                        state        <= ST_DATA;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                ST_DATA: begin
                    tx_out <= shift_reg[0];  // LSB first
                    if (baud_counter >= BAUD_DIV - 1) begin
                        baud_counter <= 8'd0;
                        shift_reg    <= {1'b0, shift_reg[7:1]};
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
                    tx_out <= 1'b1;  // Stop bit
                    if (baud_counter >= BAUD_DIV - 1) begin
                        state    <= ST_IDLE;
                        tx_ready <= 1'b1;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
