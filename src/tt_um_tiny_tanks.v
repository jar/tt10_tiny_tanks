/*
 * Copyright (c) 2025 James Ross
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tiny_tanks(
	input  wire [7:0] ui_in,    // Dedicated inputs
	output wire [7:0] uo_out,   // Dedicated outputs
	input  wire [7:0] uio_in,   // IOs: Input path
	output wire [7:0] uio_out,  // IOs: Output path
	output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
	input  wire       ena,      // always 1 when the design is powered, so you can ignore it
	input  wire       clk,      // clock
	input  wire       rst_n     // reset_n - low to reset
);

	// Unused outputs assigned to 0
	assign uio_out = 0;
	assign uio_oe  = 0;

	// Suppress unused signals warning
	wire _unused_ok = &{ena, ui_in[7], ui_in[3:0], uio_in};

	// VGA signals
	wire hsync;
	wire vsync;
	wire [5:0] RGB;
	wire video_active;
	wire [9:0] x;
	wire [9:0] y;

	// Game State
	wire [8:0] water_height = 120;
	reg [7:0] power;
	reg [7:0] angle;
	reg [2:0] map;
	reg player;

	// Tiny VGA Pmod
	assign uo_out = {hsync, RGB[0], RGB[2], RGB[4], vsync, RGB[1], RGB[3], RGB[5]};

	// VGA output
	hvsync_generator vga_sync_gen (
		.clk(clk),
		.reset(~rst_n),
		.hsync(hsync),
		.vsync(vsync),
		.display_on(video_active),
		.hpos(x),
		.vpos(y)
	);

	// Gamepad Pmod
	wire inp_b, inp_y, inp_select, inp_start, inp_up, inp_down, inp_left, inp_right, inp_a, inp_x, inp_l, inp_r, inp_is_present;

	gamepad_pmod_single driver (
		// Inputs:
		.rst_n(rst_n),
		.clk(clk),
		.pmod_data(ui_in[6]),
		.pmod_clk(ui_in[5]),
		.pmod_latch(ui_in[4]),
		// Outputs:
		.b(inp_b),
		.y(inp_y),
		.select(inp_select),
		.start(inp_start),
		.up(inp_up),
		.down(inp_down),
		.left(inp_left),
		.right(inp_right),
		.a(inp_a),
		.x(inp_x),
		.l(inp_l),
		.r(inp_r),
		.is_present(inp_is_present)
	);

	// Handle gamepad input at end of frame (60 Hz)
	always @(posedge vsync) begin
		if (~rst_n) begin
			power  <= 0;
			angle  <= 0;
			map    <= 0;
			player <= 0;
		end else begin
			power  <= inp_down ? power - 1 : (inp_up    ? power + 1 : power);
			angle  <= inp_left ? angle - 1 : (inp_right ? angle + 1 : angle);
			if (!player & inp_l) begin
				player <= 1;
			end else if (player & inp_r) begin
				player <= 0;
			end
		end
	end

	// Colors
	wire [5:0] BLACK  = {2'b00, 2'b00, 2'b00};
	wire [5:0] RED    = {2'b11, 2'b00, 2'b00};
	wire [5:0] BLUE   = {2'b00, 2'b00, 2'b11};
	wire [5:0] GREEN  = {2'b00, 2'b10, 2'b00};
	wire [5:0] WHITE  = {2'b11, 2'b11, 2'b11};
	wire [5:0] SKY    = {2'b01, 2'b01, 2'b10};
	wire [5:0] PLAYER = player ? BLUE : RED;

	wire [7:0] height_noise;
	wire [7:0] height_sine;
	wire [7:0] height_sine2;
	wire [7:0] height_sine4;

	terrain_generator terrain_noise (
		.clk(clk),
		.load(~video_active),
		.seed(8'd97),
		.height(height_noise)
	);

	terrain_lookup terrain_sine (
		.x((x << 1) + {angle, 1'b0}),
		.height(height_sine)
	);

	terrain_lookup terrain_sine2 (
		.x(x + {power, 1'b0}),
		.height(height_sine2)
	);

	terrain_lookup terrain_sine4 (
		.x((x<<2)),
		.height(height_sine4)
	);

	//wire [8:0] height = {1'b0, height_sine} + {1'b0, height_noise} - {1'b0, height_sine2 >> 1};
	wire [8:0] height = (({1'b0, height_sine} + {1'b0, height_sine2})>>1) + {1'b0, height_sine4>>1};

	wire is_border  = ((x == 191 || x == 447) && (y >= 8 && y <= 24)) || ((y == 8 || y == 16 || y == 24) && (x >= 191 && x <= 447));
	wire is_power   = (x >= 191 && x <= 191 + {2'b00, power}) && (y >= 9  && y <= 15);
	wire is_angle   = (x >= 191 && x <= 191 + {2'b00, angle}) && (y >= 17 && y <= 23);
	wire is_gui     = is_border | is_power | is_angle;
	wire is_terrain = y > {1'b0, height};
	wire is_water   = y > {1'b0, water_height};


/*	reg [12:0] tank[5:0];
	initial begin
		tank[0] = 13'b0000111110000;
		tank[1] = 13'b0001111111000;
		tank[2] = 13'b0111111111110;
		tank[3] = 13'b1010101010101;
		tank[4] = 13'b1101010101011;
		tank[5] = 13'b0111111111110;
	end*/

/*	reg [16:0] tank[7:0];
	initial begin
		tank[0] = 17'b00000111111100000;
		tank[1] = 17'b00001111111110000;
		tank[2] = 17'b00001111111110000;
		tank[3] = 17'b00111111111111100;
		tank[4] = 17'b01101010101010110;
		tank[5] = 17'b11011101110111011;
		tank[6] = 17'b01101010101010110;
		tank[7] = 17'b00111111111111100;
	end*/

	reg [24:0] tank[8:0];
	initial begin
		tank[0] = 25'b0000000111111111110000000;
		tank[1] = 25'b0000011111111111111100000;
		tank[2] = 25'b0000111111111111111110000;
		tank[3] = 25'b0111111111111111111111110;
		tank[4] = 25'b1110111110111110111110111;
		tank[5] = 25'b1101010101010101010101011;
		tank[6] = 25'b0110101010101010101010110;
		tank[7] = 25'b0011110111110111110111100;
		tank[8] = 25'b0001111111111111111111000;
	end

	reg [9:0] x_tank = 16;
	reg [9:0] y_tank = 400;
	wire [9:0] row_tank = x - x_tank;
	wire [9:0] col_tank = y - y_tank;
	//wire is_tank = ((x - x_tank) > 0 && (x - x_tank) < 17) && ((y - y_tank) > 0 && (y - y_tank) < 9);
	//wire is_tank = (row_tank < 17) && (col_tank < 8) ? tank[col_tank[2:0]][row_tank[4:0]] : 0;
	wire is_tank = (row_tank < 25) && (col_tank < 9) ? tank[col_tank[3:0]][row_tank[4:0]] : 0;

	// gui > terrain > water > sky
	//assign RGB = video_active ? (is_gui ? WHITE : (is_terrain ? GREEN : (is_water ? BLUE : SKY))) : BLACK;
	// border > power/angle > terrain > water > sky
	assign RGB = video_active ? ((is_border|is_tank) ? WHITE : ((is_power|is_angle) ? PLAYER : (is_terrain ? GREEN : (is_water ? BLUE : SKY)))) : BLACK;

	// RGB output logic
	always @(posedge clk) begin
		if (~rst_n) begin
		end
	end

endmodule

module terrain_lookup (
	input wire [9:0] x,
	output reg [7:0] height
);
	reg [6:0] v;
	always @(x) begin
		case (x[7] ? (7'd127 - x[6:0]) : x[6:0])
			7'd0  : v = 7'd1;
			7'd1  : v = 7'd2;
			7'd2  : v = 7'd4;
			7'd3  : v = 7'd5;
			7'd4  : v = 7'd7;
			7'd5  : v = 7'd9;
			7'd6  : v = 7'd10;
			7'd7  : v = 7'd12;
			7'd8  : v = 7'd13;
			7'd9  : v = 7'd15;
			7'd10 : v = 7'd16;
			7'd11 : v = 7'd18;
			7'd12 : v = 7'd19;
			7'd13 : v = 7'd21;
			7'd14 : v = 7'd22;
			7'd15 : v = 7'd24;
			7'd16 : v = 7'd26;
			7'd17 : v = 7'd27;
			7'd18 : v = 7'd29;
			7'd19 : v = 7'd30;
			7'd20 : v = 7'd32;
			7'd21 : v = 7'd33;
			7'd22 : v = 7'd35;
			7'd23 : v = 7'd36;
			7'd24 : v = 7'd38;
			7'd25 : v = 7'd39;
			7'd26 : v = 7'd41;
			7'd27 : v = 7'd42;
			7'd28 : v = 7'd44;
			7'd29 : v = 7'd45;
			7'd30 : v = 7'd46;
			7'd31 : v = 7'd48;
			7'd32 : v = 7'd49;
			7'd33 : v = 7'd51;
			7'd34 : v = 7'd52;
			7'd35 : v = 7'd54;
			7'd36 : v = 7'd55;
			7'd37 : v = 7'd56;
			7'd38 : v = 7'd58;
			7'd39 : v = 7'd59;
			7'd40 : v = 7'd61;
			7'd41 : v = 7'd62;
			7'd42 : v = 7'd63;
			7'd43 : v = 7'd65;
			7'd44 : v = 7'd66;
			7'd45 : v = 7'd67;
			7'd46 : v = 7'd69;
			7'd47 : v = 7'd70;
			7'd48 : v = 7'd71;
			7'd49 : v = 7'd72;
			7'd50 : v = 7'd74;
			7'd51 : v = 7'd75;
			7'd52 : v = 7'd76;
			7'd53 : v = 7'd78;
			7'd54 : v = 7'd79;
			7'd55 : v = 7'd80;
			7'd56 : v = 7'd81;
			7'd57 : v = 7'd82;
			7'd58 : v = 7'd84;
			7'd59 : v = 7'd85;
			7'd60 : v = 7'd86;
			7'd61 : v = 7'd87;
			7'd62 : v = 7'd88;
			7'd63 : v = 7'd89;
			7'd64 : v = 7'd90;
			7'd65 : v = 7'd91;
			7'd66 : v = 7'd93;
			7'd67 : v = 7'd94;
			7'd68 : v = 7'd95;
			7'd69 : v = 7'd96;
			7'd70 : v = 7'd97;
			7'd71 : v = 7'd98;
			7'd72 : v = 7'd99;
			7'd73 : v = 7'd100;
			7'd74 : v = 7'd101;
			7'd75 : v = 7'd102;
			7'd76 : v = 7'd102;
			7'd77 : v = 7'd103;
			7'd78 : v = 7'd104;
			7'd79 : v = 7'd105;
			7'd80 : v = 7'd106;
			7'd81 : v = 7'd107;
			7'd82 : v = 7'd108;
			7'd83 : v = 7'd109;
			7'd84 : v = 7'd109;
			7'd85 : v = 7'd110;
			7'd86 : v = 7'd111;
			7'd87 : v = 7'd112;
			7'd88 : v = 7'd112;
			7'd89 : v = 7'd113;
			7'd90 : v = 7'd114;
			7'd91 : v = 7'd114;
			7'd92 : v = 7'd115;
			7'd93 : v = 7'd116;
			7'd94 : v = 7'd116;
			7'd95 : v = 7'd117;
			7'd96 : v = 7'd118;
			7'd97 : v = 7'd118;
			7'd98 : v = 7'd119;
			7'd99 : v = 7'd119;
			7'd100: v = 7'd120;
			7'd101: v = 7'd120;
			7'd102: v = 7'd121;
			7'd103: v = 7'd121;
			7'd104: v = 7'd122;
			7'd105: v = 7'd122;
			7'd106: v = 7'd123;
			7'd107: v = 7'd123;
			7'd108: v = 7'd123;
			7'd109: v = 7'd124;
			7'd110: v = 7'd124;
			7'd111: v = 7'd124;
			7'd112: v = 7'd125;
			7'd113: v = 7'd125;
			7'd114: v = 7'd125;
			7'd115: v = 7'd126;
			7'd116: v = 7'd126;
			7'd117: v = 7'd126;
			7'd118: v = 7'd126;
			7'd119: v = 7'd126;
			7'd120: v = 7'd126;
			7'd121: v = 7'd127;
			7'd122: v = 7'd127;
			7'd123: v = 7'd127;
			7'd124: v = 7'd127;
			7'd125: v = 7'd127;
			7'd126: v = 7'd127;
			7'd127: v = 7'd127;
		endcase
		//height = {1'b0, v};
		height = x[8] ? (8'd127 - v) : (8'd127 + v);
	end
endmodule


// This performs something like an incremental average of the LFSR
module terrain_generator #(parameter NUM_BITS = 8, SHIFT = 6) (
	input wire clk,
	input wire load,
	input wire [NUM_BITS-1:0] seed,
	output reg [NUM_BITS-1:0] height
);
	wire [7:0] state;

	lfsr terrain(
		.clk(clk),
		.load(load),
		.seed(seed),
		.state(state)
	);

	wire [SHIFT-1:0] zero = 0;
	reg [NUM_BITS+SHIFT:1] height_state;
	always @(posedge clk) begin
		if (load) begin
			height_state <= 1<<(NUM_BITS+SHIFT-1);//{seed, zero};
		end else begin
			height_state <= height_state - (height_state >> SHIFT) + {zero, state};
		end
	end
	assign height = height_state[NUM_BITS+SHIFT:SHIFT+1];
endmodule
