//============================================================================
// UART Packet Transmitter
// Periodically sends audio + status data to PC via UART.
// Packet format: 16 bytes per packet, ~1920 packets/sec
//
// Byte 0:  SYNC (0xAA)
// Byte 1:  Packet type (0x01 = audio data)
// Byte 2:  audio_in[23:16]   (MSB)
// Byte 3:  audio_in[15:8]
// Byte 4:  audio_in[7:0]     (LSB)
// Byte 5:  audio_out[23:16]  (MSB)
// Byte 6:  audio_out[15:8]
// Byte 7:  audio_out[7:0]    (LSB)
// Byte 8:  VU level in (8-bit)
// Byte 9:  VU level out (8-bit)
// Byte 10: Effect enables (SW[6:0])
// Byte 11: Selected effect index (0-6)
// Byte 12: Param1 value
// Byte 13: Param2 value
// Byte 14: Master volume (4-bit, upper nibble=0)
// Byte 15: Checksum (XOR of bytes 0-14)
//============================================================================

`timescale 1ns / 1ps

module uart_packet_tx (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_clk,        // 48 kHz strobe

    // Audio data
    input  wire [23:0] audio_in,          // Raw input
    input  wire [23:0] audio_out,         // Processed output

    // Status
    input  wire [7:0]  vu_in,             // VU meter input level
    input  wire [7:0]  vu_out,            // VU meter output level
    input  wire [6:0]  effect_enables,    // Which effects are on
    input  wire [2:0]  selected_effect,   // Currently selected for edit
    input  wire [7:0]  param1_value,      // Current param1
    input  wire [7:0]  param2_value,      // Current param2
    input  wire [3:0]  master_volume,     // Volume level

    // UART TX interface
    output reg  [7:0]  tx_data,
    output reg         tx_valid,
    input  wire        tx_ready
);

    //------------------------------------------------------------------------
    // Decimation: Send every 25th sample (48000/25 = 1920 Hz)
    //------------------------------------------------------------------------
    reg [4:0] decim_counter;
    reg       send_trigger;

    always @(posedge clk) begin
        if (rst) begin
            decim_counter <= 5'd0;
            send_trigger  <= 1'b0;
        end else begin
            send_trigger <= 1'b0;
            if (sample_clk) begin
                if (decim_counter >= 5'd24) begin
                    decim_counter <= 5'd0;
                    send_trigger  <= 1'b1;
                end else begin
                    decim_counter <= decim_counter + 1'b1;
                end
            end
        end
    end

    //------------------------------------------------------------------------
    // Packet State Machine
    //------------------------------------------------------------------------
    localparam PKT_LEN = 16;

    localparam ST_IDLE    = 2'd0;
    localparam ST_LOAD    = 2'd1;
    localparam ST_SEND    = 2'd2;
    localparam ST_WAIT    = 2'd3;

    reg [1:0]  state;
    reg [3:0]  byte_index;
    reg [7:0]  packet [0:PKT_LEN-1];
    reg [7:0]  checksum;

    // Latch data on trigger
    reg [23:0] lat_in, lat_out;
    reg [7:0]  lat_vu_in, lat_vu_out;
    reg [6:0]  lat_enables;
    reg [2:0]  lat_sel;
    reg [7:0]  lat_p1, lat_p2;
    reg [3:0]  lat_vol;

    always @(posedge clk) begin
        if (rst) begin
            state      <= ST_IDLE;
            byte_index <= 4'd0;
            tx_valid   <= 1'b0;
            tx_data    <= 8'd0;
        end else begin
            tx_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (send_trigger) begin
                        // Latch all values
                        lat_in      <= audio_in;
                        lat_out     <= audio_out;
                        lat_vu_in   <= vu_in;
                        lat_vu_out  <= vu_out;
                        lat_enables <= effect_enables;
                        lat_sel     <= selected_effect;
                        lat_p1      <= param1_value;
                        lat_p2      <= param2_value;
                        lat_vol     <= master_volume;
                        state       <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    // Build packet
                    packet[0]  <= 8'hAA;                         // SYNC
                    packet[1]  <= 8'h01;                         // Type: audio
                    packet[2]  <= lat_in[23:16];                 // Audio in MSB
                    packet[3]  <= lat_in[15:8];
                    packet[4]  <= lat_in[7:0];                   // Audio in LSB
                    packet[5]  <= lat_out[23:16];                // Audio out MSB
                    packet[6]  <= lat_out[15:8];
                    packet[7]  <= lat_out[7:0];                  // Audio out LSB
                    packet[8]  <= lat_vu_in;                     // VU in
                    packet[9]  <= lat_vu_out;                    // VU out
                    packet[10] <= {1'b0, lat_enables};           // Effect enables
                    packet[11] <= {5'd0, lat_sel};               // Selected effect
                    packet[12] <= lat_p1;                        // Param 1
                    packet[13] <= lat_p2;                        // Param 2
                    packet[14] <= {4'd0, lat_vol};               // Volume

                    // Calculate checksum (XOR of bytes 0-14)
                    packet[15] <= 8'hAA ^ 8'h01 ^ 
                                  lat_in[23:16] ^ lat_in[15:8] ^ lat_in[7:0] ^
                                  lat_out[23:16] ^ lat_out[15:8] ^ lat_out[7:0] ^
                                  lat_vu_in ^ lat_vu_out ^
                                  {1'b0, lat_enables} ^ {5'd0, lat_sel} ^
                                  lat_p1 ^ lat_p2 ^ {4'd0, lat_vol};

                    byte_index <= 4'd0;
                    state      <= ST_SEND;
                end

                ST_SEND: begin
                    if (tx_ready) begin
                        tx_data  <= packet[byte_index];
                        tx_valid <= 1'b1;
                        state    <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    // Wait for UART TX to accept byte
                    if (!tx_ready) begin
                        // TX accepted, move to next byte
                        if (byte_index >= PKT_LEN - 1) begin
                            state <= ST_IDLE;  // Packet complete
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            state      <= ST_SEND;
                        end
                    end
                end
            endcase
        end
    end

endmodule
