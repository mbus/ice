`include "include/ice_def.v"

module fifo(
	input clk,
	input rst,

	input [8:0] in_data,
	input in_data_latch,
	output in_data_overflow,

	output reg [8:0] tail,
	output [8:0] out_data,
	output out_data_valid,
	input out_data_latch
);
parameter DEPTH_LOG2=9;
parameter DEPTH = (1 << DEPTH_LOG2);

//Inferred ram block
reg [DEPTH_LOG2-1:0] head;
ram #(9,DEPTH_LOG2) fr1(
	.clk(clk),
	.reset(rst),
	.in_data(in_data),
	.in_addr(head),
	.in_latch(in_data_latch),
	.out_data(out_data),
	.out_addr(tail)
);

reg [8:0] last_head, last_tail;

assign in_data_overflow = (head == tail-1);
assign out_data_valid = ~(head == tail) && (last_head != tail) && (last_tail == tail);

always @(posedge clk) begin
	if(rst) begin
		tail <= `SD 0;
		head <= `SD 0;
		last_tail <= `SD 0;
		last_head <= `SD 0;
	end else begin
		last_tail <= `SD tail;
		last_head <= `SD head;
		if(in_data_latch)
			head <= `SD head + 1;
		if(out_data_latch)
			tail <= `SD tail + 1;
	end
end


endmodule
