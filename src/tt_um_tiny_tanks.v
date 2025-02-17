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

	// VGA output
	reg show;

	// Colors
	wire [5:0] BLACK = {2'b00, 2'b00, 2'b00};
	wire [5:0] BLUE  = {2'b00, 2'b00, 2'b11};
	wire [5:0] WHITE = {2'b11, 2'b11, 2'b11};

	wire is_water = y > 475;
	assign RGB = video_active ? (is_water ? BLUE : WHITE) : BLACK;

	// RGB output logic
	always @(posedge clk) begin
		if (~rst_n) begin
			show <= 0;
		end else begin
			if (video_active) begin
				show <= 0;
			end else begin
				show <= 1;
			end
		end
	end

endmodule
