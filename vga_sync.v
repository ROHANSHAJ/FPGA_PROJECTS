// ============================================================================
// 1. VGA SYNC MODULE
// ============================================================================
module vga_sync (
    input wire clk, reset,
    output wire hsync, vsync, video_on, p_tick,
    output wire [9:0] x, y
);
    localparam H_DISPLAY = 640, H_L_BORDER = 48, H_R_BORDER = 16, H_RETRACE = 96;
    localparam H_MAX = H_DISPLAY + H_L_BORDER + H_R_BORDER + H_RETRACE - 1;
    localparam START_H_RETRACE = H_DISPLAY + H_R_BORDER;
    localparam END_H_RETRACE = H_DISPLAY + H_R_BORDER + H_RETRACE - 1;
    
    localparam V_DISPLAY = 480, V_T_BORDER = 10, V_B_BORDER = 33, V_RETRACE = 2;
    localparam V_MAX = V_DISPLAY + V_T_BORDER + V_B_BORDER + V_RETRACE - 1;
    localparam START_V_RETRACE = V_DISPLAY + V_B_BORDER;
    localparam END_V_RETRACE = V_DISPLAY + V_B_BORDER + V_RETRACE - 1;
    
    reg [1:0] pixel_reg;
    wire [1:0] pixel_next;
    wire pixel_tick;
    
    always @(posedge clk, posedge reset)
        if(reset) pixel_reg <= 0; else pixel_reg <= pixel_next;
    
    assign pixel_next = pixel_reg + 1; 
    assign pixel_tick = (pixel_reg == 0); 
    
    reg [9:0] h_count_reg, h_count_next, v_count_reg, v_count_next;
    reg vsync_reg, hsync_reg;
    wire vsync_next, hsync_next;
 
    always @(posedge clk, posedge reset)
        if(reset) begin
            v_count_reg <= 0; h_count_reg <= 0; vsync_reg <= 0; hsync_reg <= 0;
        end else begin
            v_count_reg <= v_count_next; h_count_reg <= h_count_next;
            vsync_reg <= vsync_next; hsync_reg <= hsync_next;
        end
            
    always @* begin
        h_count_next = pixel_tick ? (h_count_reg == H_MAX ? 0 : h_count_reg + 1) : h_count_reg;
        v_count_next = pixel_tick && h_count_reg == H_MAX ? (v_count_reg == V_MAX ? 0 : v_count_reg + 1) : v_count_reg;
    end
        
    assign hsync_next = (h_count_reg >= START_H_RETRACE) && (h_count_reg <= END_H_RETRACE);
    assign vsync_next = (v_count_reg >= START_V_RETRACE) && (v_count_reg <= END_V_RETRACE);
    assign video_on = (h_count_reg < H_DISPLAY) && (v_count_reg < V_DISPLAY);
    assign hsync = hsync_reg; assign vsync = vsync_reg;
    assign x = h_count_reg; assign y = v_count_reg; assign p_tick = pixel_tick;
endmodule

// ============================================================================
// 2. SEVEN-SEGMENT DISPLAY CONTROLLER (BCD SCORE)
// ============================================================================
module seven_seg_ctrl(
    input clk, reset,
    input [3:0] d0, d1, d2, d3,
    output reg [3:0] an,
    output reg [6:0] seg
);
    reg [18:0] refresh_counter;
    wire [1:0] led_activating_counter;

    always @(posedge clk or posedge reset) begin 
        if(reset) refresh_counter <= 0;
        else refresh_counter <= refresh_counter + 1;
    end 
    assign led_activating_counter = refresh_counter[18:17];

    reg [3:0] hex_val;
    always @(*) begin
        case(led_activating_counter)
            2'b00: begin an = 4'b1110; hex_val = d0; end
            2'b01: begin an = 4'b1101; hex_val = d1; end
            2'b10: begin an = 4'b1011; hex_val = d2; end
            2'b11: begin an = 4'b0111; hex_val = d3; end
        endcase
    end

    always @(*) begin
        case(hex_val)
            4'b0000: seg = 7'b1000000; 4'b0001: seg = 7'b1111001; 4'b0010: seg = 7'b0100100;
            4'b0011: seg = 7'b0110000; 4'b0100: seg = 7'b0011001; 4'b0101: seg = 7'b0010010;
            4'b0110: seg = 7'b0000010; 4'b0111: seg = 7'b1111000; 4'b1000: seg = 7'b0000000;
            4'b1001: seg = 7'b0010000; default: seg = 7'b1111111;
        endcase
    end
endmodule

// ============================================================================
// 3. SPACE SHOOTER TOP MODULE
// ============================================================================
module space_shooter (
    input wire clk,
    input wire reset_sw, // Switch 15: Master Reset Switch
    input wire btnD,     // Bottom Button: Start Game
    input wire btnC,     // Center Button: Pause / Resume
    input wire btnL, btnR, btnU, // Left, Right, Shoot
    input wire [1:0] sw, // Level selection
    output wire hsync, vsync,
    output wire [3:0] vgaRed, vgaGreen, vgaBlue,
    output wire [6:0] seg,
    output wire [3:0] an
);

    // State Machine
    localparam START=0, PLAY=1, PAUSE=2, GAMEOVER=3;
    reg [1:0] state = START;

    // Pause Button Debounce
    reg [19:0] debounce_counter;
    reg pause_btn_clean, pause_d;
    always @(posedge clk) begin
        debounce_counter <= debounce_counter + 1;
        if (debounce_counter == 0) pause_btn_clean <= btnC;
        pause_d <= pause_btn_clean;
    end
    wire pause_pulse = pause_btn_clean & ~pause_d;

    // VGA & Frame Tick
    wire video_on;
    wire [9:0] x, y;
    // Pass the Master Reset Switch into the VGA sync as well
    vga_sync vga_unit (.clk(clk), .reset(reset_sw), .hsync(hsync), .vsync(vsync), .video_on(video_on), .x(x), .y(y));
    wire refr_tick = (y == 481) && (x == 0);

    reg [7:0] anim_scroll;
    always @(posedge clk) if (refr_tick) anim_scroll <= anim_scroll + 1;

    // Score Counter
    reg [3:0] sc0, sc1, sc2, sc3;
    seven_seg_ctrl sseg_unit (.clk(clk), .reset(reset_sw), .d0(sc0), .d1(sc1), .d2(sc2), .d3(sc3), .an(an), .seg(seg));

    // Dynamic Background Color Index
    reg [2:0] bg_color_idx = 0;

    // Objects
    localparam SHIP_W = 32, SHIP_H = 16, SHIP_SPEED = 4;
    localparam ENEMY_W = 32, ENEMY_H = 16;
    localparam BULLET_W = 4, BULLET_H = 8, BULLET_SPEED = 8;
    
    // Levels & Difficulty Scaling
    wire [2:0] max_enemies = (sw == 2'b00) ? 1 : (sw == 2'b01) ? 2 : (sw == 2'b10) ? 3 : 4;
    wire [9:0] ENEMY_SPEED = (sw == 2'b00) ? 2 : (sw == 2'b01) ? 3 : (sw == 2'b10) ? 4 : 5;
    wire [11:0] ENEMY_COLOR = (sw == 2'b00) ? 12'hF00 : (sw == 2'b01) ? 12'hF0F : (sw == 2'b10) ? 12'h0FF : 12'hFFF;
    
    // Registers
    reg [9:0] ship_x = 304; 
    wire [9:0] ship_y = 440; 
    
    reg [9:0] en_x [0:3];
    reg [9:0] en_y [0:3];
    reg [3:0] en_dir; 
    reg [3:0] en_act; 
    reg [5:0] en_tmr [0:3]; 
    
    reg [9:0] bullet_x = 0, bullet_y = 0;
    reg bullet_active = 0;

    integer i;
    reg hit_flag;

    // Game Logic Update
    always @(posedge clk) begin
        // MASTER RESET (Priority 1)
        if (reset_sw) begin
            state <= START;
            ship_x <= 304; 
            bullet_active <= 0;
            sc0 <= 0; sc1 <= 0; sc2 <= 0; sc3 <= 0;
            bg_color_idx <= 0; // Reset background color
            for (i=0; i<4; i=i+1) en_act[i] <= 0;
        end
        // START GAME BUTTON
        else if (btnD && (state == START || state == GAMEOVER)) begin
            state <= PLAY;
            ship_x <= 304; bullet_active <= 0;
            sc0 <= 0; sc1 <= 0; sc2 <= 0; sc3 <= 0;
            bg_color_idx <= 0;
            for (i=0; i<4; i=i+1) begin
                en_act[i] <= (i < max_enemies) ? 1 : 0;
                en_x[i] <= 50 + (i * 120);
                en_y[i] <= 40;
                en_dir[i] <= i % 2; 
                en_tmr[i] <= 0;
            end
        end 
        // PAUSE LOGIC
        else if (pause_pulse) begin
            if (state == PLAY) state <= PAUSE;
            else if (state == PAUSE) state <= PLAY;
        end
        // PLAY STATE LOGIC
        else if (state == PLAY && refr_tick) begin
            
            // 1. Ship Movement
            if (btnL && (ship_x > 0)) ship_x <= ship_x - SHIP_SPEED;
            if (btnR && (ship_x < (640 - SHIP_W))) ship_x <= ship_x + SHIP_SPEED;

            // 2. Bullet Logic & Swarm Collision Check
            hit_flag = 0; 
            
            if (bullet_active) begin
                for (i=0; i<4; i=i+1) begin
                    if (en_act[i] && (bullet_x + BULLET_W >= en_x[i]) && (bullet_x <= en_x[i] + ENEMY_W) &&
                        (bullet_y <= en_y[i] + ENEMY_H) && (bullet_y + BULLET_H >= en_y[i]) && !hit_flag) begin
                        
                        bullet_active <= 0; 
                        en_act[i] <= 0; 
                        en_tmr[i] <= 0; 
                        hit_flag = 1;
                    end
                end
                
                if (!hit_flag) begin
                    if (bullet_y < BULLET_SPEED) bullet_active <= 0; 
                    else bullet_y <= bullet_y - BULLET_SPEED;
                end
            end else if (btnU) begin
                bullet_active <= 1;
                bullet_x <= ship_x + (SHIP_W / 2) - (BULLET_W / 2);
                bullet_y <= ship_y;
            end

            // 3. Score & Background Color Increment
            if (hit_flag) begin
                bg_color_idx <= bg_color_idx + 1; // Cycle background color

                // BCD Score Math
                if (sc0 == 9) begin
                    sc0 <= 0;
                    if (sc1 == 9) begin sc1 <= 0; if (sc2 == 9) begin sc2 <= 0; sc3 <= sc3 + 1; end else sc2 <= sc2 + 1; end
                    else sc1 <= sc1 + 1;
                end else sc0 <= sc0 + 1;
            end

            // 4. Enemy Swarm Movement & Respawning
            for (i=0; i<4; i=i+1) begin
                if (en_act[i]) begin
                    if (en_dir[i] == 0) begin 
                        if (en_x[i] < (640 - ENEMY_W)) en_x[i] <= en_x[i] + ENEMY_SPEED;
                        else begin en_dir[i] <= 1; en_y[i] <= en_y[i] + 16; end 
                    end else begin 
                        if (en_x[i] >= ENEMY_SPEED) en_x[i] <= en_x[i] - ENEMY_SPEED;
                        else begin en_dir[i] <= 0; en_y[i] <= en_y[i] + 16; end 
                    end
                    
                    if (en_y[i] + ENEMY_H >= ship_y) state <= GAMEOVER;
                    
                end else if (i < max_enemies) begin
                    en_tmr[i] <= en_tmr[i] + 1;
                    if (en_tmr[i] >= 30 + (i*10)) begin 
                        en_act[i] <= 1;
                        en_y[i] <= 40;
                        en_x[i] <= (x + (i * 133)) % (640 - ENEMY_W); 
                        en_tmr[i] <= 0;
                    end
                end
            end
        end
    end

    // --- Dynamic Background Palette ---
    reg [11:0] current_bg_color;
    always @* begin
        case(bg_color_idx)
            3'd0: current_bg_color = 12'h000; // Black space
            3'd1: current_bg_color = 12'h102; // Deep Purple
            3'd2: current_bg_color = 12'h012; // Deep Cyan
            3'd3: current_bg_color = 12'h020; // Dark Green
            3'd4: current_bg_color = 12'h200; // Dark Crimson
            3'd5: current_bg_color = 12'h210; // Dark Orange/Brown
            3'd6: current_bg_color = 12'h002; // Navy Blue
            3'd7: current_bg_color = 12'h111; // Dark Charcoal
        endcase
    end

    // --- Sprites & Rendering ---
    wire ship_on = (x >= ship_x) && (x < ship_x + SHIP_W) && (y >= ship_y) && (y < ship_y + SHIP_H);
    wire ship_core = ship_on && (x >= ship_x + 8) && (x < ship_x + 24); 
    wire ship_wing = ship_on && ~ship_core;                             

    wire enemy_on = (en_act[0] && x >= en_x[0] && x < en_x[0] + ENEMY_W && y >= en_y[0] && y < en_y[0] + ENEMY_H) ||
                    (en_act[1] && x >= en_x[1] && x < en_x[1] + ENEMY_W && y >= en_y[1] && y < en_y[1] + ENEMY_H) ||
                    (en_act[2] && x >= en_x[2] && x < en_x[2] + ENEMY_W && y >= en_y[2] && y < en_y[2] + ENEMY_H) ||
                    (en_act[3] && x >= en_x[3] && x < en_x[3] + ENEMY_W && y >= en_y[3] && y < en_y[3] + ENEMY_H);
    
    wire enemy_core = enemy_on && (x[3] ^ y[3]); 
    wire bullet_on = bullet_active && (x >= bullet_x) && (x < bullet_x + BULLET_W) && (y >= bullet_y) && (y < bullet_y + BULLET_H);

    // UI & Backgrounds
    wire top_bar_on = (y >= 8 && y <= 12);
    wire bot_bar_on = (y >= 468 && y <= 472);
    wire star_on = (x[3:0] ^ (y[3:0] + anim_scroll[4:1])) == 4'b1111 && x[6:5] == 2'b10;

    reg [11:0] rgb;

    always @* begin
        if (~video_on)
            rgb = 12'h000; 
        else if (top_bar_on || bot_bar_on)
            rgb = 12'h0F8; 
        else if (ship_core)
            rgb = 12'h0FF; 
        else if (ship_wing)
            rgb = 12'h00F; 
        else if (enemy_core)
            rgb = ENEMY_COLOR; 
        else if (enemy_on)
            rgb = 12'h333; 
        else if (bullet_on)
            rgb = 12'hF80; 
        else begin
            if (state == START) 
                rgb = (x[4] ^ y[4]) ? 12'h005 : 12'h002; 
            else if (state == PLAY) 
                rgb = star_on ? 12'hFFF : current_bg_color; // Apply Dynamic Background Here
            else if (state == PAUSE) 
                rgb = (y[1]) ? 12'h222 : 12'h444; 
            else if (state == GAMEOVER) 
                rgb = (anim_scroll[4]) ? 12'hF00 : 12'h600; 
            else 
                rgb = 12'h000;
        end
    end

    assign vgaRed   = rgb[11:8];
    assign vgaGreen = rgb[7:4];
    assign vgaBlue  = rgb[3:0];

endmodule