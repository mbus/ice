
`include "mbus_def_ice.v"

module mbus_layer_wrapper_ice(
	input clk,
	input reset,

	input MASTER_NODE,
	input CPU_LAYER,

	input 	CLKIN, 
	output 	CLKOUT,
	input 	DIN, 
	output 	DOUT, 

	//Master input bus
	input [7:0] ma_data,
	input [7:0] ma_addr,
	input ma_data_valid,
	input ma_frame_valid,
	inout sl_overflow,
	
	//Slave output bus
	inout [7:0] sl_data,
	output [1:0] sl_arb_request,
	input [1:0] sl_arb_grant,
	input sl_data_latch,
	
	//Global counter for 'time-tagging'
	input [7:0] global_counter,
	output reg incr_ctr,
	
	output [3:0] debug
);

assign sl_arb_request[1] = 1'b0; //Not using second arb request yet!

/*mbus_clk_gen mbcg1(
	.sys_clk(clk),
	.reset(reset),
	.clk_div(mbus_clk_div),
	.mbus_clk(mbus_clk)
);*/

//Bus interface takes care of all buffering, etc for discrete data...
reg rx_frame_valid;
reg rx_char_latch;
reg [7:0] status_bits;
reg [63:0] data_sr;

wire hd_data_valid, hd_frame_valid, hd_data_latch, hd_header_done, hd_is_fragment, hd_is_empty;
wire [7:0] hd_header_eid;
reg hd_header_done_clear;
reg send_flag, send_ctr, send_status;
wire [7:0] rx_frame_data = (send_flag) ? 8'h42 : (send_ctr) ? global_counter : (send_status) ? status_bits : data_sr[63:56];
wire [7:0] tx_char;
wire rx_frame_data_latch = rx_char_latch | send_ctr | send_status;//TODO: Is send_flag needed here as well?!

bus_interface #(8'h42,1,1,1) bi0(
	.clk(clk),
	.rst(reset),
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[0]),
	.sl_arb_grant(sl_arb_grant[0]),
	.sl_data_latch(sl_data_latch),
	.in_frame_data(tx_char),
	.in_frame_data_valid(hd_data_valid),//tx_char_valid),
	.in_frame_valid(hd_frame_valid),//tx_req),
	.in_frame_data_latch(hd_data_latch),
	.out_frame_data(rx_frame_data),
	.out_frame_valid(rx_frame_valid),
	.out_frame_data_latch(rx_frame_data_latch)
);
header_decoder hd0(
	.clk(clk),
	.rst(reset),
	.in_frame_data(tx_char),
	.in_frame_data_valid(hd_data_valid),
	.in_frame_valid(hd_frame_valid),
	.header_eid(hd_header_eid),
	.is_fragment(hd_is_fragment),
	.frame_data_latch(hd_data_latch),
	.header_done(hd_header_done),
	.packet_is_empty(hd_is_empty),
	.header_done_clear(hd_header_done_clear)
);
assign tx_char_valid = hd_data_valid & hd_header_done;

wire [31:0] mbus_rxaddr, mbus_txaddr;
wire [31:0] mbus_rxdata, mbus_txdata;

//wire mbus_txpend, mbus_txreq, mbus_txack, mbus_txfail, mbus_txresp_ack, mbus_txsucc;
wire mbus_rxpend, mbus_rxreq, mbus_rxfail, mbus_rxbcast;
//wire mbus_clk;
//wire [15:0] mbus_clk_div;

reg mbus_rxack;

assign debug = {CLKIN, mbus_rxfail, mbus_rxreq, mbus_rxack};
reg mbus_reset, mbus_reset_pend;
 
mbus_layer_wrapper mclw1(
    .RESETn(~mbus_reset),
	
    .CLKIN(CLKIN),
    .DIN(DIN),
    .CLKOUT(CLKOUT),
    .DOUT(DOUT),
	
	//For now, just paying attention to RX, as we are snooping everything...
    .RX_ADDR(mbus_rxaddr),
    .RX_DATA(mbus_rxdata),
    .RX_REQ(mbus_rxreq),
    .RX_ACK(mbus_rxack),
    .RX_BROADCAST(mbus_rxbcast),
    .RX_FAIL(mbus_rxfail),
    .RX_PEND(mbus_rxpend)
   );
   
reg [3:0] state, next_state;
reg [1:0] cur_status_bits;

reg reset_status, store_status;
reg store_data;
reg next_mb_ack;
reg [1:0] rxreq_db, rxfail_db;
reg [3:0] data_ctr;
reg [7:0] state_ctr;
reg [7:0] data_ctr_tot;
wire rxreq = rxreq_db[1];
wire rxfail = rxfail_db[1];
reg first_message;
   
parameter STATE_IDLE = 0;
parameter STATE_HDR0 = 1;
parameter STATE_HDR1 = 2;
parameter STATE_RX = 3;
parameter STATE_RX_WAIT = 4;
parameter STATE_RX_FRAGMENT = 5;
parameter STATE_RX_CHECK_STATUS = 6;
parameter STATE_RX_END = 7;
parameter STATE_FAIL_ACK = 8;
   
always @(posedge clk) begin
	if(reset) begin
		state <= STATE_IDLE;
		status_bits <= 8'h00;
		mbus_rxack <= 1'b0;
		data_ctr <= 3'd0;
		first_message <= 1'b1;
		state_ctr <= 8'h00;
		mbus_reset_pend <= 1'b1;
		mbus_reset <= 1'b0;
	end else begin
		if(mbus_reset_pend) begin
			mbus_reset_pend <= 1'b0;
			mbus_reset <= 1'b1;
		end else begin
			mbus_reset <= 1'b0;
		end
		state <= next_state;
		mbus_rxack <= next_mb_ack;
		rxreq_db <= {rxreq_db[0], mbus_rxreq};
		rxfail_db <= {rxfail_db[0], mbus_rxfail};
		
		if(reset_status) begin
			status_bits <= 8'h00;
			first_message <= 1'b1;
			data_ctr_tot <= 8'h00;
		end else if(store_status) begin
			cur_status_bits <= {mbus_rxfail, mbus_rxpend};
			status_bits <= status_bits | {4'b0000, mbus_rxfail, mbus_rxbcast, 2'b00};
		end
			
		if(next_state != state) begin
			state_ctr <= 0;
		end else begin
			state_ctr <= state_ctr + 1;
		end

		if(store_data == 1'b1) begin
			data_ctr_tot <= data_ctr_tot + 1;
			first_message <= 1'b0;
			if(first_message) begin
				data_ctr <= 4'd7;
				data_sr <= {mbus_rxaddr, mbus_rxdata};
			end else begin
				data_ctr <= 4'd3;
				data_sr <= {mbus_rxdata, 32'd0};
			end
		end else if(rx_char_latch) begin
			data_sr <= {data_sr[55:0], 8'h00};
			data_ctr <= data_ctr - 1;
		end
	end
end
   
always @* begin
	next_state = state;
	reset_status = 1'b0;
	store_status = 1'b0;
	store_data = 1'b0;
	send_status = 1'b0;
	rx_frame_valid = 1'b0;
	rx_char_latch = 1'b0;
	next_mb_ack = 1'b0;
	send_flag = 1'b0;
	send_ctr = 1'b0;
	incr_ctr = 1'b0;
	hd_header_done_clear = 1'b0;
	case(state)
		STATE_IDLE: begin
			reset_status = 1'b1;
			if(rxreq)
				next_state = STATE_HDR0;
			else if(rxfail)
				next_state = STATE_FAIL_ACK;
		end
		
		STATE_HDR0: begin
			rx_frame_valid = 1'b1;
			send_flag = 1'b1;
			next_state = STATE_HDR1;
		end
		
		STATE_HDR1: begin
			rx_frame_valid = 1'b1;
			send_ctr = 1'b1;
			if(state_ctr[1]) begin
				incr_ctr = 1'b1;
				next_state = STATE_RX;
			end
		end
		
		STATE_RX: begin
			store_status = 1'b1;
			store_data = 1'b1;
			next_mb_ack = 1'b1;
			rx_frame_valid = 1'b1;
			next_state = STATE_RX_WAIT;
		end
		
		STATE_RX_WAIT: begin
			rx_char_latch = 1'b1;
			rx_frame_valid = 1'b1;
			if(data_ctr == 0)
				next_state = STATE_RX_CHECK_STATUS;
			else if(data_ctr_tot == 8'hfe)
				next_state = STATE_RX_FRAGMENT;
		end
		
		STATE_RX_FRAGMENT: begin
			if(state_ctr[0])
				next_state = STATE_RX_WAIT;
		end
		
		STATE_RX_CHECK_STATUS: begin
			rx_frame_valid = 1'b1;
			if(cur_status_bits[0]) begin //Pending more data
				if(rxreq) begin
					next_state = STATE_RX;
				end
			end else if(cur_status_bits[1]) begin //Failed RX
				next_state = STATE_RX_END;
			end else begin
				next_state = STATE_RX_END;
			end
		end
		
		STATE_RX_END: begin
			rx_frame_valid = 1'b1;
			send_status = 1'b1;
			next_state = STATE_IDLE;
		end
		
		STATE_FAIL_ACK: begin
			next_mb_ack = 1'b1;
			if(state_ctr[1]) begin
				next_state = STATE_IDLE;
			end
		end
	endcase
end


endmodule