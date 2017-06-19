`include "include/ice_def.v"

module goc_int(
	input clk,
	input reset,
	
	output GOC_PAD,
	
	//GOC Settings
	input [21:0] goc_speed,
	input goc_polarity,
	
	//Master input bus
	input [7:0] ma_data,
	input [7:0] ma_addr,
	input ma_data_valid,
	input ma_frame_valid,
	inout sl_overflow,

	//Slave output bus
	input [8:0] sl_addr,
	inout [8:0] sl_tail,
	input sl_latch_tail,
	inout [8:0] sl_data,
	output sl_arb_request,
	input sl_arb_grant
);

//Bus interface takes care of all buffering, etc for discrete data...
reg ackgen_generate_ack;
wire [7:0] ack_message_data;
wire ack_message_data_valid;
wire ack_message_frame_valid;

wire hd_frame_valid, hd_data_latch, hd_header_done;
wire [7:0] hd_header_eid;
wire [8:0] hd_frame_tail, hd_frame_addr;
wire hd_frame_latch_tail;

wire [8:0] in_char;
wire hd_frame_next;
wire hd_frame_data_valid;
bus_interface #(8'h66,1,1,0) bi0(
	.clk(clk),
	.rst(reset),
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request),
	.sl_arb_grant(sl_arb_grant),
	.in_frame_data(in_char),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_valid(hd_frame_data_valid),
	.in_frame_tail(hd_frame_tail),
	.in_frame_addr(hd_frame_addr),
	.in_frame_latch_tail(hd_frame_latch_tail),
	.out_frame_data(ack_message_data),
	.out_frame_valid(ack_message_frame_valid),
	.out_frame_data_latch(ack_message_data_valid)
);
header_decoder hd0(
	.clk(clk),
	.rst(reset),
	.in_frame_data(in_char),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_valid(hd_frame_data_valid),
	.in_frame_tail(hd_frame_tail),
	.in_frame_next(hd_frame_next),
	.in_frame_addr(hd_frame_addr),
	.in_frame_latch_tail(hd_frame_latch_tail),
	.header_eid(hd_header_eid),
	.header_done(hd_header_done),
	.header_done_clear(1'b0)
);

/************************************************************
 *Ack generator is used to easily create ACK & NAK sequences*
 ************************************************************/
ack_generator ag0(
	.clk(clk),
	.reset(reset),
	
	.generate_ack(ackgen_generate_ack),
	.generate_nak(1'b0),
	.eid_in(hd_header_eid),
	
    .message_wait(1'h0),
	.message_data(ack_message_data),
	.message_data_valid(ack_message_data_valid),
	.message_frame_valid(ack_message_frame_valid)
);

wire pwm_out;
assign GOC_PAD = pwm_out ^ goc_polarity;

pwm_mod pm0(
	.clk(clk), 
	.resetn(~reset), 
	.fifo_din(in_char), 
	.fifo_RE(hd_frame_next), 
	.fifo_empty(~hd_frame_valid), 
	.start_tx(hd_header_done), 
	.PWM_OUT(pwm_out),
	.base_counter(goc_speed)
);

//One of the simplest state machines, because pwm_mod takes care of the rest
parameter STATE_IDLE = 0;
parameter STATE_TRANSMITTING = 1;
parameter STATE_ACK = 2;

reg [3:0] state, next_state;
always @* begin
	next_state = state;
	ackgen_generate_ack = 1'b0;
	
	case(state)
		STATE_IDLE: begin
			if(hd_header_done)
				next_state = STATE_TRANSMITTING;
		end
		
		STATE_TRANSMITTING: begin
			if(~hd_header_done) begin
				next_state = STATE_ACK;
			end
		end
		
		STATE_ACK: begin
			ackgen_generate_ack = 1'b1;
			next_state = STATE_IDLE;
		end
	endcase
end

always @(posedge clk) begin
	if(reset) begin
		state <= `SD STATE_IDLE;
	end else begin
		state <= `SD next_state;
	end
end

endmodule
