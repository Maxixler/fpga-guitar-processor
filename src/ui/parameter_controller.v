//============================================================================
// Parameter Controller
// Manages effect parameters using buttons for adjustment and switches
// for effect selection. Each effect has default parameters that can be
// fine-tuned with BTNU/BTND/BTNL/BTNR buttons.
// BTNC cycles through active effects for parameter editing.
//============================================================================

`timescale 1ns / 1ps

module parameter_controller (
    input  wire        clk,
    input  wire        rst,
    // Debounced button inputs
    input  wire        btn_center,     // Cycle effect selection
    input  wire        btn_up,         // Param 1 increase
    input  wire        btn_down,       // Param 1 decrease
    input  wire        btn_left,       // Param 2 decrease
    input  wire        btn_right,      // Param 2 increase
    // Effect enables
    input  wire [6:0]  effect_enables, // Which effects are on

    // Current selection output (for display)
    output reg [2:0]   selected_effect,// 0-6 effect index
    output reg [7:0]   display_value,  // Parameter value for display

    // All effect parameters
    output reg [7:0]   ng_threshold,
    output reg [7:0]   dist_gain,
    output reg [7:0]   dist_tone,
    output reg         dist_mode,
    output reg [7:0]   od_drive,
    output reg [7:0]   od_mix,
    output reg [7:0]   delay_time,
    output reg [7:0]   delay_feedback,
    output reg [7:0]   delay_mix,
    output reg [7:0]   reverb_decay,
    output reg [7:0]   reverb_mix,
    output reg [7:0]   chorus_rate,
    output reg [7:0]   chorus_depth,
    output reg [7:0]   trem_rate,
    output reg [7:0]   trem_depth,
    output reg [1:0]   trem_wave
);

    //------------------------------------------------------------------------
    // Default Parameter Values
    //------------------------------------------------------------------------
    localparam DEF_NG_THRESH   = 8'd20;
    localparam DEF_DIST_GAIN   = 8'd128;
    localparam DEF_DIST_TONE   = 8'd180;
    localparam DEF_OD_DRIVE    = 8'd128;
    localparam DEF_OD_MIX      = 8'd200;
    localparam DEF_DELAY_TIME  = 8'd100;   // ~0.53s
    localparam DEF_DELAY_FB    = 8'd128;   // 50%
    localparam DEF_DELAY_MIX   = 8'd128;   // 50%
    localparam DEF_REV_DECAY   = 8'd150;
    localparam DEF_REV_MIX     = 8'd100;
    localparam DEF_CHOR_RATE   = 8'd80;
    localparam DEF_CHOR_DEPTH  = 8'd128;
    localparam DEF_TREM_RATE   = 8'd100;
    localparam DEF_TREM_DEPTH  = 8'd180;

    //------------------------------------------------------------------------
    // Parameter Increment
    //------------------------------------------------------------------------
    localparam STEP = 8'd5;

    // Safe increment/decrement functions
    function [7:0] safe_inc;
        input [7:0] val;
        input [7:0] step;
        begin
            if (val > 8'd255 - step)
                safe_inc = 8'd255;
            else
                safe_inc = val + step;
        end
    endfunction

    function [7:0] safe_dec;
        input [7:0] val;
        input [7:0] step;
        begin
            if (val < step)
                safe_dec = 8'd0;
            else
                safe_dec = val - step;
        end
    endfunction

    //------------------------------------------------------------------------
    // Effect Selection Cycling
    // BTNC cycles through enabled effects
    //------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            selected_effect <= 3'd0;
        end else if (btn_center) begin
            // Find next enabled effect
            case (selected_effect)
                3'd0: selected_effect <= 3'd1;
                3'd1: selected_effect <= 3'd2;
                3'd2: selected_effect <= 3'd3;
                3'd3: selected_effect <= 3'd4;
                3'd4: selected_effect <= 3'd5;
                3'd5: selected_effect <= 3'd6;
                3'd6: selected_effect <= 3'd0;
                default: selected_effect <= 3'd0;
            endcase
        end
    end

    //------------------------------------------------------------------------
    // Parameter Adjustment
    //------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            // Load defaults
            ng_threshold   <= DEF_NG_THRESH;
            dist_gain      <= DEF_DIST_GAIN;
            dist_tone      <= DEF_DIST_TONE;
            dist_mode      <= 1'b0;
            od_drive       <= DEF_OD_DRIVE;
            od_mix         <= DEF_OD_MIX;
            delay_time     <= DEF_DELAY_TIME;
            delay_feedback <= DEF_DELAY_FB;
            delay_mix      <= DEF_DELAY_MIX;
            reverb_decay   <= DEF_REV_DECAY;
            reverb_mix     <= DEF_REV_MIX;
            chorus_rate    <= DEF_CHOR_RATE;
            chorus_depth   <= DEF_CHOR_DEPTH;
            trem_rate      <= DEF_TREM_RATE;
            trem_depth     <= DEF_TREM_DEPTH;
            trem_wave      <= 2'd0;
        end else begin
            case (selected_effect)
                3'd0: begin // Noise Gate
                    if (btn_up)   ng_threshold <= safe_inc(ng_threshold, STEP);
                    if (btn_down) ng_threshold <= safe_dec(ng_threshold, STEP);
                end

                3'd1: begin // Distortion
                    if (btn_up)    dist_gain <= safe_inc(dist_gain, STEP);
                    if (btn_down)  dist_gain <= safe_dec(dist_gain, STEP);
                    if (btn_right) dist_tone <= safe_inc(dist_tone, STEP);
                    if (btn_left)  dist_tone <= safe_dec(dist_tone, STEP);
                end

                3'd2: begin // Overdrive
                    if (btn_up)    od_drive <= safe_inc(od_drive, STEP);
                    if (btn_down)  od_drive <= safe_dec(od_drive, STEP);
                    if (btn_right) od_mix <= safe_inc(od_mix, STEP);
                    if (btn_left)  od_mix <= safe_dec(od_mix, STEP);
                end

                3'd3: begin // Delay
                    if (btn_up)    delay_time <= safe_inc(delay_time, STEP);
                    if (btn_down)  delay_time <= safe_dec(delay_time, STEP);
                    if (btn_right) delay_feedback <= safe_inc(delay_feedback, STEP);
                    if (btn_left)  delay_feedback <= safe_dec(delay_feedback, STEP);
                end

                3'd4: begin // Reverb
                    if (btn_up)    reverb_decay <= safe_inc(reverb_decay, STEP);
                    if (btn_down)  reverb_decay <= safe_dec(reverb_decay, STEP);
                    if (btn_right) reverb_mix <= safe_inc(reverb_mix, STEP);
                    if (btn_left)  reverb_mix <= safe_dec(reverb_mix, STEP);
                end

                3'd5: begin // Chorus
                    if (btn_up)    chorus_rate <= safe_inc(chorus_rate, STEP);
                    if (btn_down)  chorus_rate <= safe_dec(chorus_rate, STEP);
                    if (btn_right) chorus_depth <= safe_inc(chorus_depth, STEP);
                    if (btn_left)  chorus_depth <= safe_dec(chorus_depth, STEP);
                end

                3'd6: begin // Tremolo
                    if (btn_up)    trem_rate <= safe_inc(trem_rate, STEP);
                    if (btn_down)  trem_rate <= safe_dec(trem_rate, STEP);
                    if (btn_right) trem_depth <= safe_inc(trem_depth, STEP);
                    if (btn_left)  trem_depth <= safe_dec(trem_depth, STEP);
                end
            endcase
        end
    end

    //------------------------------------------------------------------------
    // Display Value (show param1 of selected effect)
    //------------------------------------------------------------------------
    always @(*) begin
        case (selected_effect)
            3'd0: display_value = ng_threshold;
            3'd1: display_value = dist_gain;
            3'd2: display_value = od_drive;
            3'd3: display_value = delay_time;
            3'd4: display_value = reverb_decay;
            3'd5: display_value = chorus_rate;
            3'd6: display_value = trem_rate;
            default: display_value = 8'd0;
        endcase
    end

endmodule
