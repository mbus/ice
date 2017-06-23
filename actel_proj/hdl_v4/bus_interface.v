`include "include/ice_def.v"

module bus_interface(
	input clk,
	input rst,
	
	//Master bus
	input [7:0] ma_data,
	input [7:0] ma_addr,
	input ma_data_valid,
	input ma_frame_valid,
	inout sl_overflow,
	
	//Slave bus
	inout [8:0] sl_data,
	input [8:0] sl_addr,
	inout [8:0] sl_tail,
	output sl_arb_request,
	input sl_arb_grant,
	input sl_latch_tail,
	
	//Local input data interface
	output [8:0] in_frame_data,
	output [8:0] in_frame_tail,
	input [8:0] in_frame_addr,
	output in_frame_valid,
	output in_frame_data_valid,
	input in_frame_latch_tail,
	
	//Local output data interface
	input [7:0] out_frame_data,
	input out_frame_valid,
	input out_frame_data_latch);
parameter ADDR = 0;
parameter INCLUDE_INPUT_FIFO = 0;
parameter INCLUDE_OUTPUT_FIFO = 0;
parameter SUPPORTS_FRAGMENTATION = 0;
parameter INPUT_FIFO_DEPTH_LOG2 = 9;
parameter OUTPUT_FIFO_DEPTH_LOG2 = 9;

//Local wires/buses
wire in_mf_overflow;
wire addr_match = (ma_addr == ADDR);
wire [8:0] local_sl_data;
wire [8:0] local_sl_tail;
reg last_frame_valid;
wire insert_fvbit = last_frame_valid & ~(ma_frame_valid & addr_match);

//Only include an input FIFO if it has been requested
generate
	if(INCLUDE_INPUT_FIFO) begin
		message_fifo #(
        .DEPTH_LOG2( INPUT_FIFO_DEPTH_LOG2) 
        ) mf0(
			.clk(clk),
			.rst(rst),
			.in_data(ma_data),
			.in_data_latch(ma_data_valid & addr_match),
			.in_frame_valid(ma_frame_valid & addr_match),
			.in_data_overflow(in_mf_overflow),
			.tail(in_frame_tail),
			.out_data(in_frame_data),
			.out_data_addr(in_frame_addr),
			.out_frame_valid(in_frame_valid),
			.out_frame_data_valid(in_frame_data_valid),
			.latch_tail(in_frame_latch_tail)
		);
		assign sl_overflow = (addr_match) ? in_mf_overflow : 1'bz;
	end else begin
		always @(posedge clk) begin
			last_frame_valid <= `SD ma_frame_valid & addr_match;
		end
		assign in_mf_overflow = 1'b0;
		assign in_frame_data = {insert_fvbit,ma_data};
		assign in_frame_valid = addr_match & ma_frame_valid;
		assign in_frame_data_valid = (addr_match & ma_data_valid) | insert_fvbit;
		assign sl_overflow = (addr_match) ? in_mf_overflow : 1'bz;
	end
endgenerate

//Output FIFO will always be needed in this case
wire sl_arb_data_valid;
generate
	if(INCLUDE_OUTPUT_FIFO) begin
		message_fifo #(
        .DEPTH_LOG2( OUTPUT_FIFO_DEPTH_LOG2) 
        ) mf1(
			.clk(clk),
			.rst(rst),
			.in_data(out_frame_data),
			.in_data_latch(out_frame_data_latch),
			.in_frame_valid(out_frame_valid),
			.in_data_overflow(),//TODO: No assignment to this for now (nothing we can really do about it since there's no back-pressure!)
			.tail(local_sl_tail),
			.out_data(local_sl_data),
			.out_data_addr(sl_addr),
			.out_frame_valid(sl_arb_request),
            .out_frame_data_valid(sl_arb_data_valid ),
			.latch_tail(sl_latch_tail & sl_arb_grant)
		);
		assign sl_data = (sl_arb_grant) ? local_sl_data : 9'bzzzzzzzzz;
		assign sl_tail = (sl_arb_grant) ? local_sl_tail : 9'bzzzzzzzzz;
	end else begin
		//TODO: This should just be able to store 1 ACK/NAK... (right now it doesn't do anything =(
		assign sl_data = (sl_arb_grant) ? 8'd0 : 8'bzzzzzzzz;
		assign sl_arb_request = 1'b0;
	end
endgenerate

endmodule
