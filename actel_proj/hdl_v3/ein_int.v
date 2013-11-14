module ein_int(
	input clk,
	input reset,
	
	output EMO_PAD,
	output EDI_PAD,
	output ECI_PAD,
	
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
	input sl_arb_grant,
	input sl_data_latch
);

//Bus interface takes care of all buffering, etc for discrete data...
reg ackgen_generate_ack;
wire [7:0] ack_message_data;
wire ack_message_data_valid;
wire ack_message_frame_valid;

wire hd_data_valid, hd_frame_valid, hd_data_latch, hd_header_done, hd_is_fragment;
wire [7:0] hd_header_eid;

wire [7:0] in_char;
wire in_char_latch;
bus_interface #(8'h65,1,1,0) bi0(
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
	.sl_data_latch(sl_data_latch),
	.in_frame_data(in_char),
	.in_frame_data_valid(hd_data_valid),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_latch(in_char_latch | hd_data_latch),
	.out_frame_data(ack_message_data),
	.out_frame_valid(ack_message_frame_valid),
	.out_frame_data_latch(ack_message_data_valid)
);
header_decoder hd0(
	.clk(clk),
	.rst(reset),
	.in_frame_data(in_char),
	.in_frame_data_valid(hd_data_valid),
	.in_frame_valid(hd_frame_valid),
	.header_eid(hd_header_eid),
	.is_fragment(hd_is_fragment),
	.frame_data_latch(hd_data_latch),
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
	
	.message_data(ack_message_data),
	.message_data_valid(ack_message_data_valid),
	.message_frame_valid(ack_message_frame_valid)
);

//Change one of EMO, EDI, ECI every 200 us
ein_mod #(4000,12) pm0(
	.clk(clk), 
	.resetn(~reset), 
	.fifo_din(in_char), 
	.fragment(hd_is_fragment),
	.fifo_RE(in_char_latch), 
	.fifo_empty(~hd_frame_valid), 
	.start_tx(hd_header_done), 
	.EMO_OUT(EMO_PAD),
	.EDI_OUT(EDI_PAD),
	.ECI_OUT(ECI_PAD)
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
			if(~hd_frame_valid) begin
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
		state <= STATE_IDLE;
	end else begin
		state <= next_state;
	end
end

endmodule
