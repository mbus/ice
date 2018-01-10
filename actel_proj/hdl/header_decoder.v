`include "include/ice_def.v"

module header_decoder(
	input clk,
	input rst,
	input [8:0] in_frame_data,
	input in_frame_valid,//New
	input in_frame_data_valid,
	input [8:0] in_frame_tail,//New
	input in_frame_next,//New
	output [8:0] in_frame_addr,//New
	output reg in_frame_latch_tail,//New
	output reg [7:0] header_eid,
	output reg header_done,
	output reg packet_is_empty,
	output reg is_fragment,
	input header_done_clear
);

reg frame_data_latch;
reg [8:0] in_frame_addr_offset;
assign in_frame_addr = in_frame_tail + in_frame_addr_offset;

parameter STATE_IDLE = 0;
parameter STATE_RECORD_EID = 1;
parameter STATE_SKIP_LEN = 2;
parameter STATE_WAIT = 3;
parameter STATE_WAIT_TAIL_LATCH = 4;

reg [3:0] state, next_state;
reg latch_eid, latch_is_fragment, set_header_done;
always @( posedge clk) begin
	if(rst) begin
		state <= `SD STATE_IDLE;
		header_done <= `SD 1'b0;
		is_fragment <= `SD 1'b0;
		packet_is_empty <= `SD 1'b0;
		in_frame_addr_offset <= `SD 0;
	end else begin
		state <= `SD next_state;

		if(latch_eid)
			header_eid <= `SD in_frame_data[7:0];

		if(header_done_clear | (state == STATE_IDLE))
			header_done <= `SD 1'b0;
		if(set_header_done) begin
			header_done <= `SD 1'b1;
			if(in_frame_data[7:0] == 8'h00)
				packet_is_empty <= `SD 1'b1;
			else
				packet_is_empty <= `SD 1'b0;
		end

		if(state == STATE_IDLE)
			in_frame_addr_offset <= `SD 0;
		if(frame_data_latch | in_frame_next)
			in_frame_addr_offset <= `SD in_frame_addr_offset + 1;

		if(latch_is_fragment) begin
			if(in_frame_data[7:0] == 8'hFF)
				is_fragment <= `SD 1'b1;
			else
				is_fragment <= `SD 1'b0;
		end
	end
end

always @* begin
	next_state = state;
	in_frame_latch_tail = 1'b0;
	frame_data_latch = 1'b0;
	set_header_done = 1'b0;
	latch_is_fragment = 1'b0;
	latch_eid = 1'b0;
	
	case(state)
		STATE_IDLE: begin
			frame_data_latch = in_frame_valid;
			if(in_frame_valid) begin
				next_state = STATE_RECORD_EID;
			end
		end
		
		STATE_RECORD_EID: begin
			frame_data_latch = in_frame_data_valid;
			latch_eid = 1'b1;
			if(in_frame_data_valid) begin
				next_state = STATE_SKIP_LEN;
			end
		end
		
		STATE_SKIP_LEN: begin
			frame_data_latch = in_frame_data_valid;
			latch_is_fragment = in_frame_data_valid;
			set_header_done = in_frame_data_valid;
			if(in_frame_data_valid) begin
				next_state = STATE_WAIT;
			end
		end
		
		STATE_WAIT: begin
			if(in_frame_data[8] & in_frame_data_valid) begin
				frame_data_latch = 1'b1;
				next_state = STATE_WAIT_TAIL_LATCH;
			end
		end

		STATE_WAIT_TAIL_LATCH: begin
			in_frame_latch_tail = 1'b1;
			next_state = STATE_IDLE;
		end
	endcase
end

endmodule
