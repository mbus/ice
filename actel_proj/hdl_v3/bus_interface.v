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
	inout [7:0] sl_data,
	input [8:0] sl_addr,
	inout [8:0] sl_tail,
	output sl_arb_request,
	input sl_arb_grant,
	input sl_data_latch,
	input sl_latch_tail,
	
	//Local input data interface
	output [7:0] in_frame_data,
	output in_frame_data_valid,
	output in_frame_valid,
	input in_frame_data_latch,
	
	//Local output data interface
	input [7:0] out_frame_data,
	input out_frame_valid,
	input out_frame_data_latch,
	
	output [7:0] debug);
parameter ADDR = 0;
parameter INCLUDE_INPUT_FIFO = 0;
parameter INCLUDE_OUTPUT_FIFO = 0;
parameter SUPPORTS_FRAGMENTATION = 0;

//Local wires/buses
wire in_mf_overflow;
wire addr_match = (ma_addr == ADDR);
wire [7:0] local_sl_data;
wire [8:0] local_sl_tail;

//Only include an input FIFO if it has been requested
generate
	if(INCLUDE_INPUT_FIFO) begin
		message_fifo #(9,0) mf0(
			.clk(clk),
			.rst(rst),
			.in_data(ma_data),
			.in_data_latch(ma_data_valid & addr_match),
			.in_frame_valid(ma_frame_valid & addr_match),
			.in_data_overflow(in_mf_overflow),
			.populate_frame_length(1'b0),
			.out_data(in_frame_data),
			.out_frame_valid(in_frame_valid),
			.out_data_latch(in_frame_data_latch)
		);
		assign in_frame_data_valid = 1'b1;
		assign sl_overflow = (addr_match) ? in_mf_overflow : 1'bz;
	end else begin
		assign in_mf_overflow = 1'b0;
		assign in_frame_data = ma_data;
		assign in_frame_valid = addr_match & ma_frame_valid;
		assign in_frame_data_valid = addr_match & ma_data_valid;
		assign sl_overflow = (addr_match) ? in_mf_overflow : 1'bz;
	end
endgenerate

//Output FIFO will always be needed in this case
generate
	if(INCLUDE_OUTPUT_FIFO) begin
		message_fifo #(9) mf1(
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
			.out_data_latch(sl_data_latch & sl_arb_grant)
			.latch_tail(sl_latch_tail & sl_arb_grant)
		);
		assign sl_data = (sl_arb_grant) ? local_sl_data : 8'bzzzzzzzz;
		assign sl_tail = (sl_arb_grant) ? local_sl_tail : 9'bzzzzzzzzz;
	end else begin
		//TODO: This should just be able to store 1 ACK/NAK... (right now it doesn't do anything =(
		assign sl_data = (sl_arb_grant) ? 8'd0 : 8'bzzzzzzzz;
		assign sl_arb_request = 1'b0;
	end
endgenerate

endmodule
