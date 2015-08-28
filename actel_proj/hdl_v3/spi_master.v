`include "include/ice_def.v"

module micron_flash_impl(
	input clk,
	input rst,

	output reg spi_mosi,
	input spi_miso,
	output reg spi_clk,
	output reg spi_csn,

	input in_latch,
	input [7:0] in_data,
	input in_continue,
	output reg [7:0] out_data,
	output reg out_done_latch,
	output reg out_ready
);

parameter CLK_DIV_BIT = 2;

parameter STATE_IDLE = 0;

reg [3:0] state, next_state;

always @(posedge rst or posedge clk) begin
	if(rst) begin
		state <= `SD STATE_IDLE;
		in_continue_latched <= `SD 1'b0;
		clk_counter <= `SD 0;
		out_data <= `SD 0;
	end else begin
		state <= `SD next_state;
		
		spi_clk <= `SD clk_counter[CLK_DIV_BIT];
		if(clk_counter_en) begin
			clk_counter <= `SD clk_counter + 1;
		end else if(clk_counter_clear) begin
			clk_counter <= `SD 0;
		end

		if(latch_in_data) begin
			data_sr <= `SD in_data;
			in_continue_latched <= `SD in_continue;
		end

		if(shift_mosi_out) begin
			data_sr <= `SD {data_sr[6:0], 1'b0};
		end
		if(shift_miso_in) begin
			out_data <= `SD {out_data[6:0], spi_miso};
		end
	end
end

always @* begin
	next_state = state;
	next_csn = 1'b1;
	latch_in_data = 1'b0;
	shift_mosi_out = 1'b0;
	shift_miso_in = 1'b0;
	clk_counter_clear = 1'b0;
	out_ready = 1'b0;
	out_done_latch = 1'b0;

	case(state)
		STATE_IDLE: begin
			out_ready = 1'b1;
			next_csn = in_continue_latched;
			latch_in_data = in_latch;
			clk_counter_clear = 1'b1;
			if(latch_in_data)
				next_state = STATE_TRANS1;
		end

		STATE_TRANS1: begin
			next_csn = 1'b0;
			clk_counter_en = 1'b1;
			shift_mosi_out = (clk_counter[CLK_DIV_BIT:0] == {{CLK_DIV_BIT}{1'b0}});
			shift_miso_in = (clk_counter[CLK_DIV_BIT:0] == {1'b0, {{CLK_DIV_BIT-1}{1'b1}});
			if(clk_counter[CLK_DIV_BIT+3])
				next_state = STATE_TRANS2;
		end

		STATE_TRANS2: begin
			next_csn = 1'b0;
			out_done_latch = 1'b1;
			next_state = STATE_IDLE;
		end
	endcase
end

endmodule
