`include "include/ice_def.v"

module message_fifo(
	input clk,
	input rst,

	input [7:0] in_data,
	input in_data_latch,
	input in_frame_valid,
	output in_data_overflow,

	output reg [8:0] tail,
	input [8:0] out_data_addr,
	output [8:0] out_data,
	output out_frame_valid,
	output out_frame_data_valid,
	input latch_tail
);
parameter DEPTH_LOG2=9;
parameter DEPTH = (1 << DEPTH_LOG2);

reg last_frame_valid;
wire insert_fvbit = (last_frame_valid & ~in_frame_valid);
wire insert_start = (~last_frame_valid & in_frame_valid);

//Inferred ram block
reg [DEPTH_LOG2-1:0] head;
reg [DEPTH_LOG2-3:0] num_valid_frames;
wire [8:0] ram_wr_data;
reg [8:0] out_data_addr_reg;
wire ram_wr_latch;
ram #(9,DEPTH_LOG2) fr1(
	.clk(clk),
	.reset(rst),
	.in_data(ram_wr_data),
	.in_addr(head),
	.in_latch(ram_wr_latch),
	.out_data(out_data),
	.out_addr(out_data_addr_reg[DEPTH_LOG2-1:0])
);

assign ram_wr_data = {insert_fvbit,in_data};
assign ram_wr_latch = (in_data_latch | insert_fvbit | insert_start); 

assign in_data_overflow = (head == tail-1);
assign out_frame_valid = (num_valid_frames > 0);

assign out_frame_data_valid = (out_data_addr == out_data_addr_reg);

always @(posedge clk) begin
	if(rst) begin
		last_frame_valid <= `SD 1'b0;
		out_data_addr_reg <= `SD 9'd0;
		num_valid_frames <= `SD 0;
		tail <= `SD 0;
		head <= `SD 0;
	end else begin
		out_data_addr_reg <= `SD out_data_addr;

		last_frame_valid <= `SD in_frame_valid;
		if(insert_fvbit)
			num_valid_frames <= `SD num_valid_frames + 1;
		//TODO: What if both happen at once?
		if(latch_tail)
			num_valid_frames <= `SD num_valid_frames - 1;
		if(ram_wr_latch)
			head <= `SD head + 1;
		if(latch_tail)
			tail <= `SD out_data_addr;
	end
end


endmodule
