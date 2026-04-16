//============================================================================
// XADC Interface Module
// Interfaces with the Xilinx XADC IP core for analog audio input.
// Reads auxiliary channel 6 at 48 kHz sample rate.
// 
// NOTE: This module wraps the XADC Wizard IP which must be generated
//       in Vivado 2025.1 with the following settings:
//       - Interface: DRP
//       - Timing Mode: Continuous
//       - Channel: VAUXP6/VAUXN6 enabled
//       - Averaging: None (for lowest latency)
//============================================================================

`timescale 1ns / 1ps
`include "../utils/fixed_point_math.vh"

module xadc_interface (
    input  wire        clk,            // 100 MHz system clock
    input  wire        rst,
    input  wire        vauxp6,         // XADC positive analog input
    input  wire        vauxn6,         // XADC negative analog input
    output reg  [23:0] audio_sample,   // 24-bit signed audio output (Q1.23)
    output reg         sample_valid,   // Pulse when new sample is ready
    output wire [11:0] raw_adc_data    // Raw 12-bit ADC data for debug
);

    //------------------------------------------------------------------------
    // Sample Rate Generator: 48 kHz from 100 MHz
    // 100_000_000 / 48_000 = 2083.33... → use 2083 count
    //------------------------------------------------------------------------
    localparam SAMPLE_DIV = 2083;
    reg [11:0] sample_counter;
    reg        sample_strobe;

    always @(posedge clk) begin
        if (rst) begin
            sample_counter <= 12'd0;
            sample_strobe  <= 1'b0;
        end else begin
            if (sample_counter >= SAMPLE_DIV - 1) begin
                sample_counter <= 12'd0;
                sample_strobe  <= 1'b1;
            end else begin
                sample_counter <= sample_counter + 1'b1;
                sample_strobe  <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------------------
    // XADC DRP Interface
    // The XADC Wizard IP core is instantiated here.
    // Ensure you generate it with Vivado IP Catalog.
    //------------------------------------------------------------------------
    wire [15:0] xadc_do;         // Data output (top 12 bits = ADC data)
    wire        xadc_drdy;       // Data ready
    wire        xadc_eoc;        // End of conversion
    wire        xadc_eos;        // End of sequence
    wire [4:0]  xadc_channel;    // Current channel
    wire        xadc_busy;       // XADC busy
    
    reg  [6:0]  xadc_daddr;     // DRP address
    reg         xadc_den;        // DRP enable
    reg         xadc_dwe;        // DRP write enable
    reg  [15:0] xadc_di;         // DRP data input

    // XADC Wizard IP Instantiation
    // Generate this IP in Vivado: IP Catalog → XADC Wizard
    // Name it: xadc_wiz_0
    xadc_wiz_0 u_xadc (
        .daddr_in   (xadc_daddr),       // 7-bit DRP address
        .dclk_in    (clk),              // DRP clock (100 MHz)
        .den_in     (xadc_den),         // DRP enable
        .di_in      (xadc_di),          // 16-bit DRP data input
        .dwe_in     (xadc_dwe),         // DRP write enable
        .do_out     (xadc_do),          // 16-bit DRP data output
        .drdy_out   (xadc_drdy),        // DRP data ready
        .reset_in   (rst),              // Reset
        .vp_in      (1'b0),             // Dedicated VP (not used)
        .vn_in      (1'b0),             // Dedicated VN (not used)
        .vauxp6     (vauxp6),           // Aux channel 6 positive
        .vauxn6     (vauxn6),           // Aux channel 6 negative
        .channel_out(xadc_channel),     // Current channel
        .eoc_out    (xadc_eoc),         // End of conversion
        .eos_out    (xadc_eos),         // End of sequence
        .busy_out   (xadc_busy),        // XADC busy
        .alarm_out  ()                  // Alarms (unused)
    );

    //------------------------------------------------------------------------
    // DRP Read State Machine
    // Reads ADC data from channel 6 register (address 0x16)
    //------------------------------------------------------------------------
    localparam ADDR_AUX6 = 7'h16;   // Status register for Aux Channel 6

    localparam ST_IDLE    = 2'd0;
    localparam ST_REQUEST = 2'd1;
    localparam ST_WAIT    = 2'd2;
    localparam ST_DONE    = 2'd3;

    reg [1:0] drp_state;
    reg [15:0] adc_raw_reg;

    always @(posedge clk) begin
        if (rst) begin
            drp_state   <= ST_IDLE;
            xadc_daddr  <= 7'd0;
            xadc_den    <= 1'b0;
            xadc_dwe    <= 1'b0;
            xadc_di     <= 16'd0;
            adc_raw_reg <= 16'd0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;
            xadc_den     <= 1'b0;

            case (drp_state)
                ST_IDLE: begin
                    if (sample_strobe) begin
                        drp_state <= ST_REQUEST;
                    end
                end

                ST_REQUEST: begin
                    xadc_daddr <= ADDR_AUX6;
                    xadc_den   <= 1'b1;
                    xadc_dwe   <= 1'b0;
                    drp_state  <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (xadc_drdy) begin
                        adc_raw_reg <= xadc_do;
                        drp_state   <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    sample_valid <= 1'b1;
                    drp_state    <= ST_IDLE;
                end
            endcase
        end
    end

    //------------------------------------------------------------------------
    // ADC Data Conversion: 12-bit unsigned → 24-bit signed (Q1.23)
    // XADC output: upper 12 bits of 16-bit register
    // ADC range 0-4095 maps to analog 0V-1V
    // With 0.5V DC bias: 2048 = zero, 0 = -0.5V, 4095 = +0.5V
    // Convert: subtract 2048, then scale to Q1.23
    //------------------------------------------------------------------------
    wire [11:0] adc_12bit = adc_raw_reg[15:4];  // Top 12 bits
    wire signed [12:0] adc_centered = {1'b0, adc_12bit} - 13'd2048;

    assign raw_adc_data = adc_12bit;

    // Convert ADC data when DRP read completes
    always @(posedge clk) begin
        if (rst) begin
            audio_sample <= 24'd0;
        end else if (drp_state == ST_DONE) begin
            // adc_centered: -2048 to +2047 (13-bit signed)
            // Shift left by 11 to get 24-bit Q1.23 format
            // This maps the full ADC range to the full 24-bit audio range
            audio_sample <= {adc_centered[12:0], 11'd0};
        end
    end

endmodule
