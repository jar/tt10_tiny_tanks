// Linear Feedback Shift Register. For other bit-widths, see:
// https://docs.amd.com/v/u/en-US/xapp052
module lfsr #(parameter NUM_BITS = 8) (
	input wire clk,
	input wire load,
	input wire [NUM_BITS-1:0] seed,
	output reg [NUM_BITS-1:0] state
);
	reg [NUM_BITS:1] lfsr_state;
	wire feedback = lfsr_state[8] ^~ lfsr_state[6] ^~ lfsr_state[5] ^~ lfsr_state[4]; // 8-bit LFSR
	//wire feedback = lfsr_state[15] ^~ lfsr_state[14]; // 15-bit LFSR
	always @(posedge clk) begin
		if (load) begin
			lfsr_state <= seed;
		end else begin
			lfsr_state <= { lfsr_state[NUM_BITS-1:1], feedback };
		end
	end
	assign state = lfsr_state;
endmodule
