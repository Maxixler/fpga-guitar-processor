//============================================================================
// UART Command Receiver
// Parses incoming 6-byte command packets from PC.
//
// Command format:
// Byte 0: SYNC (0x55)
// Byte 1: CMD type (0x01=SetParam, 0x02=ToggleEffect, 0x03=SetVolume)
// Byte 2: Effect index (0-6)
// Byte 3: Param index (0 or 1)
// Byte 4: Value (0-255)
// Byte 5: Checksum (XOR of bytes 0-4)
//============================================================================

`timescale 1ns / 1ps

module uart_cmd_rx (
    input  wire       clk,
    input  wire       rst,

    // UART RX interface
    input  wire [7:0] rx_data,
    input  wire       rx_valid,

    // Command outputs
    output reg        cmd_valid,         // Command received (pulse)
    output reg [7:0]  cmd_type,          // Command type
    output reg [2:0]  cmd_effect,        // Effect index
    output reg        cmd_param_idx,     // Param 0 or 1
    output reg [7:0]  cmd_value          // Parameter value
);

    localparam CMD_LEN  = 6;
    localparam SYNC_BYTE = 8'h55;

    // Receive buffer
    reg [7:0] rx_buf [0:CMD_LEN-1];
    reg [2:0] rx_count;

    // State
    localparam ST_SYNC = 1'd0;
    localparam ST_DATA = 1'd1;

    reg state;

    always @(posedge clk) begin
        if (rst) begin
            state     <= ST_SYNC;
            rx_count  <= 3'd0;
            cmd_valid <= 1'b0;
            cmd_type  <= 8'd0;
            cmd_effect    <= 3'd0;
            cmd_param_idx <= 1'b0;
            cmd_value     <= 8'd0;
        end else begin
            cmd_valid <= 1'b0;

            if (rx_valid) begin
                case (state)
                    ST_SYNC: begin
                        if (rx_data == SYNC_BYTE) begin
                            rx_buf[0] <= rx_data;
                            rx_count  <= 3'd1;
                            state     <= ST_DATA;
                        end
                    end

                    ST_DATA: begin
                        rx_buf[rx_count] <= rx_data;

                        if (rx_count >= CMD_LEN - 1) begin
                            // All bytes received — verify checksum
                            begin : verify
                                reg [7:0] calc_checksum;
                                calc_checksum = rx_buf[0] ^ rx_buf[1] ^ rx_buf[2] ^ 
                                                rx_buf[3] ^ rx_buf[4];

                                if (rx_data == calc_checksum) begin
                                    // Valid command
                                    cmd_valid     <= 1'b1;
                                    cmd_type      <= rx_buf[1];
                                    cmd_effect    <= rx_buf[2][2:0];
                                    cmd_param_idx <= rx_buf[3][0];
                                    cmd_value     <= rx_buf[4];
                                end
                            end
                            state    <= ST_SYNC;
                            rx_count <= 3'd0;
                        end else begin
                            rx_count <= rx_count + 1'b1;
                        end
                    end
                endcase
            end
        end
    end

endmodule
