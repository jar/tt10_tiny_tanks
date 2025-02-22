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
		power <= inp_down ? power - 1 : (inp_up    ? power + 1 : power);
		angle <= inp_left ? angle - 1 : (inp_right ? angle + 1 : angle);
	end

	// Colors
	wire [5:0] BLACK = {2'b00, 2'b00, 2'b00};
	wire [5:0] BLUE  = {2'b00, 2'b00, 2'b11};
	wire [5:0] GREEN = {2'b00, 2'b10, 2'b00};
	wire [5:0] WHITE = {2'b11, 2'b11, 2'b11};
	wire [5:0] SKY   = {2'b01, 2'b01, 2'b10};

	wire [7:0] height;
	terrain_generator terrain (
		.clk(clk),
		.load(~video_active),
		.seed(8'd97),
		.height(height)
	);

	wire is_border = ((x == 191 || x == 447) && (y >= 8 && y <= 24)) || ((y == 8 || y == 16 || y == 24) && (x >= 191 && x <= 447));
	wire is_power = (x >= 191 && x <= 191 + {2'b00, power}) && (y >= 9  && y <= 15);
	wire is_angle = (x >= 191 && x <= 191 + {2'b00, angle}) && (y >= 17 && y <= 23);
	wire is_gui = is_border | is_power | is_angle;
	wire is_terrain = y > {2'b00, height};
	wire is_water = y > {1'b0, water_height};

	// gui > terrain > water > sky
	assign RGB = video_active ? (is_gui ? WHITE : (is_terrain ? GREEN : (is_water ? BLUE : SKY))) : BLACK;

	// RGB output logic
	always @(posedge clk) begin
		if (~rst_n) begin
		end
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
			height_state <= {seed, zero};
		end else begin
			height_state <= height_state - (height_state >> SHIFT) + {zero, state};
		end
	end
	assign height = height_state[NUM_BITS+SHIFT:SHIFT+1];
endmodule
