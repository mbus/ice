`include "include/ice_def.v"

//`include "mbus_def_ice.v"

module mbus_layer_wrapper_ice(
	input clk,
	input reset,

	input [19:0] mbus_long_addr,
	input  [3:0] mbus_short_addr_override,
	input MASTER_NODE,
	input mbus_snoop_enabled,
	input [21:0] mbus_clk_div,
	input mbus_tx_prio,

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
	input [8:0] sl_addr,
	inout [8:0] sl_tail,
	input sl_latch_tail,
	inout [8:0] sl_data,
	output [1:0] sl_arb_request,
	input [1:0] sl_arb_grant,
	
	//Global counter for 'time-tagging'
	input [7:0] global_counter,
	output reg incr_ctr,
	
	output [3:0] debug
);


//Bus interface takes care of all buffering, etc for discrete data...
reg rx_frame_valid;
reg rx_char_latch;
reg [7:0] status_bits;
reg [63:0] data_sr;

wire hd_frame_valid, hd_frame_data_valid, hd_header_done, hd_is_fragment, hd_is_empty;
wire [8:0] hd_frame_tail, hd_frame_addr;
wire hd_frame_latch_tail;
wire [7:0] hd_header_eid;
reg hd_header_done_clear;
reg shift_in_txaddr, shift_in_txdata;
wire hd_frame_next = shift_in_txaddr | shift_in_txdata;
reg send_flag, send_ctr, send_status;
wire [7:0] rx_frame_data = (send_flag) ? 8'h62 : (send_ctr) ? global_counter : (send_status) ? status_bits : data_sr[63:56];
wire [8:0] tx_char;
wire       tx_char_valid;
wire rx_frame_data_latch = rx_char_latch | send_ctr | send_status;//TODO: Is send_flag needed here as well?!

//MBus clock generation logic
reg mbus_clk;
reg [21:0] mbus_clk_counter;

always @(posedge clk) begin
	if(reset) begin
		mbus_clk_counter <= `SD 0;
		mbus_clk <= `SD 1'b0;
	end else begin
		mbus_clk_counter <= `SD mbus_clk_counter + 1;
		if(mbus_clk_counter == mbus_clk_div) begin
			mbus_clk_counter <= `SD 0;
			mbus_clk <= `SD ~mbus_clk;
		end
	end
end

bus_interface #(8'h62,1,1,1) bi0(
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
	.sl_arb_request(sl_arb_request[0]),
	.sl_arb_grant(sl_arb_grant[0]),
	.in_frame_data(tx_char),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_valid(hd_frame_data_valid),
	.in_frame_tail(hd_frame_tail),
	.in_frame_addr(hd_frame_addr),
	.in_frame_latch_tail(hd_frame_latch_tail),
	.out_frame_data(rx_frame_data),
	.out_frame_valid(rx_frame_valid),
	.out_frame_data_latch(rx_frame_data_latch)
);
header_decoder hd0(
	.clk(clk),
	.rst(reset),
	.in_frame_data(tx_char),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_valid(hd_frame_data_valid),
	.in_frame_tail(hd_frame_tail),
	.in_frame_next(hd_frame_next),
	.in_frame_addr(hd_frame_addr),
	.in_frame_latch_tail(hd_frame_latch_tail),
	.header_eid(hd_header_eid),
	.is_fragment(hd_is_fragment),
	.header_done(hd_header_done),
	.packet_is_empty(hd_is_empty),
	.header_done_clear(hd_header_done_clear)
);
assign tx_char_valid = hd_frame_data_valid & hd_header_done & ~tx_char[8];

/************************************************************
 *Ack generator is used to easily create ACK & NAK sequences*
 ************************************************************/
reg ackgen_generate_ack, ackgen_generate_nak;
wire [7:0] ack_message_data;
wire ack_message_data_valid;
wire ack_message_frame_valid;
ack_generator ag0(
	.clk(clk),
	.reset(reset),
	
	.generate_ack(ackgen_generate_ack),
	.generate_nak(ackgen_generate_nak),
	.eid_in(hd_header_eid),
	
	.message_data(ack_message_data),
	.message_data_valid(ack_message_data_valid),
	.message_frame_valid(ack_message_frame_valid)
);

//Only using an output message fifo here because we should be able to keep up with requests in real-time
wire [8:0] mf_sl_data;
wire [8:0] mf_sl_tail;
assign sl_data = (sl_arb_grant[1]) ? mf_sl_data : 9'bzzzzzzzzz;
assign sl_tail = (sl_arb_grant[1]) ? mf_sl_tail : 9'bzzzzzzzzz;
message_fifo 
    //only used for ACK/NAKs
    #(  .DEPTH_LOG2(2), 
        .DEPTH(1<<2) 
    )
    mf1
    (
	.clk(clk),
	.rst(reset),
	
	.in_data(ack_message_data),
	.in_data_latch(ack_message_data_valid),
	.in_frame_valid(ack_message_frame_valid),

	.tail(mf_sl_tail),
	.out_data_addr(sl_addr),
	.out_data(mf_sl_data),
	.out_frame_valid(sl_arb_request[1]),
	.latch_tail(sl_latch_tail & sl_arb_grant[1])
);


reg [31:0] mbus_txaddr, mbus_txdata;
wire [31:0] mbus_rxdata, mbus_rxaddr;
wire [1:0] ice_export_control_bits;

wire mbus_txack, mbus_txfail, mbus_txsucc;
reg mbus_txpend, mbus_txpend_next, mbus_txreq, mbus_txreq_next, mbus_txresp_ack;
wire mbus_rxpend, mbus_rxreq, mbus_rxfail, mbus_rxbcast;
//wire mbus_clk;
//wire [15:0] mbus_clk_div;

reg mbus_rxack;

assign debug = {CLKIN, mbus_rxfail, mbus_rxreq, mbus_rxack};

/* The MBus controller expects a register interface to hold the short address
* configuration. With ICE, the short address may either be set by a command to
* the board or via an enumerate command over MBus. */

// These hold values as assigned by the MBus controller
reg       mbus_register_assigned_addr_valid;
reg [3:0] mbus_register_assigned_addr;

// These are the values fed back into MBus
reg       assigned_addr_valid;
reg [3:0] assigned_addr;

// And the remaining control signals
wire [3:0] assigned_addr_out;
wire       assigned_addr_write;
wire       assigned_addr_invalidN;

always @* begin
	if (mbus_short_addr_override != 4'hf) begin
		// ICE user set an address
		assigned_addr_valid = 1'b1;
		assigned_addr = mbus_short_addr_override;
	end else begin
		assigned_addr_valid = mbus_register_assigned_addr_valid;
		assigned_addr = mbus_register_assigned_addr;
	end
end

// Note: This register is reset with the ICE reset and not the mbus_reset
always @(posedge mbus_clk )
begin
	if (reset) begin
		mbus_register_assigned_addr_valid <= `SD 1'b0;
		mbus_register_assigned_addr <= `SD 4'b1111;
	end else begin
		if (assigned_addr_write) begin
			mbus_register_assigned_addr_valid <= `SD 1'b1;
			mbus_register_assigned_addr <= `SD assigned_addr_out;
		end else if (~assigned_addr_invalidN) begin
			mbus_register_assigned_addr_valid <= `SD 1'b0;
			mbus_register_assigned_addr <= `SD 4'b1111;
		end
	end
end

mbus_general_layer_wrapper mclw1(
    .RESETn(~reset),

    .CLK_EXT(mbus_clk),
    .MASTER_EN(MASTER_NODE),
    .mbus_snoop_enabled(mbus_snoop_enabled),
    .ADDRESS(mbus_long_addr),

    .ASSIGNED_ADDR_IN(assigned_addr),
    .ASSIGNED_ADDR_OUT(assigned_addr_out),
    .ASSIGNED_ADDR_VALID(assigned_addr_valid),
    .ASSIGNED_ADDR_WRITE(assigned_addr_write),
    .ASSIGNED_ADDR_INVALIDn(assigned_addr_invalidN),
	
    .CLKIN(CLKIN),
    .DIN(DIN),
    .CLKOUT(CLKOUT),
    .DOUT(DOUT),
	
    //RX Ports
    .RX_ADDR(mbus_rxaddr),
    .RX_DATA(mbus_rxdata),
    .RX_REQ(mbus_rxreq),
    .RX_ACK(mbus_rxack),
    .RX_BROADCAST(mbus_rxbcast),
    .RX_FAIL(mbus_rxfail),
    .RX_PEND(mbus_rxpend),
    .ice_export_control_bits(ice_export_control_bits),

    //TX Ports
    .TX_ADDR(mbus_txaddr),
    .TX_DATA(mbus_txdata),
    .TX_PEND(mbus_txpend),
    .TX_REQ(mbus_txreq),
    .TX_PRIORITY(mbus_tx_prio),
    .TX_ACK(mbus_txack),
    .TX_FAIL(mbus_txfail),
    .TX_SUCC(mbus_txsucc),
    .TX_RESP_ACK(mbus_txresp_ack)
);
//TODO: Implement logic for mbus_txpend, mbus_txreq, mbus_txack, mbus_txfail, mbus_txresp_ack, mbus_txsucc, mbus_txdata, mbus_txaddr
   
reg [4:0] state, next_state;
reg [1:0] cur_status_bits;

reg reset_status, store_status;
reg store_data;
reg next_mb_ack;
reg [1:0] rxreq_db, rxfail_db;
reg [3:0] data_ctr;
reg [7:0] state_ctr;
reg [7:0] data_ctr_tot;
reg [3:0] shift_count;
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
parameter STATE_TX_START = 9;
parameter STATE_TX_DATA = 10;
parameter STATE_TX_WAIT_PEND = 11;
//parameter STATE_TX_WORD0 = 12; //unused
parameter STATE_TX_WORD1 = 13;
parameter STATE_TX_FRAGMENT = 14;
parameter STATE_TX_END0 = 15;
parameter STATE_TX_END1 = 16;

   
//Doesn't need an async reset
always @(posedge clk) begin
	if(reset) begin
		state <= `SD STATE_IDLE;
		status_bits <= `SD 8'h00;
		mbus_rxack <= `SD 1'b0;
		data_ctr <= `SD 3'd0;
		first_message <= `SD 1'b1;
		state_ctr <= `SD 8'h00;
		shift_count <= `SD 4'd0;
		mbus_txdata <= `SD 32'd0;
		mbus_txaddr <= `SD 32'd0;
		mbus_txpend <= `SD 1'b0;
		mbus_txreq <= `SD 1'b0;
		mbus_txresp_ack <= `SD 1'b0;
	end else begin
		state <= `SD next_state;

		mbus_rxack <= `SD next_mb_ack;
		rxreq_db <= `SD {rxreq_db[0], mbus_rxreq};
		rxfail_db <= `SD {rxfail_db[0], mbus_rxfail};
		
		if(reset_status) begin
			status_bits <= `SD 8'h00;
			first_message <= `SD 1'b1;
			data_ctr_tot <= `SD 8'h00;
		end else if(store_status) begin
			cur_status_bits <= `SD {mbus_rxfail, mbus_rxpend};
			status_bits <= `SD status_bits | {4'b0000, mbus_rxfail, mbus_rxbcast, ice_export_control_bits};
		end
			
		if(next_state != state) begin
			state_ctr <= `SD 0;
			shift_count <= `SD 0;
		end else begin
			state_ctr <= `SD state_ctr + 1;
			if(shift_in_txaddr | shift_in_txdata)
				shift_count <= `SD shift_count + 4'd1;
		end

		if(store_data == 1'b1) begin
			data_ctr_tot <= `SD data_ctr_tot + 1;
			first_message <= `SD 1'b0;
			if(first_message) begin
				data_ctr <= `SD 4'd7;
				data_sr <= `SD {mbus_rxaddr, mbus_rxdata};
			end else begin
				data_ctr <= `SD 4'd3;
				data_sr <= `SD {mbus_rxdata, 32'd0};
			end
		end else if(rx_char_latch) begin
			data_sr <= `SD {data_sr[55:0], 8'h00};
			data_ctr <= `SD data_ctr - 1;
		end

		//Logic to shift in TXDATA, TXADDR
		if(shift_in_txdata) begin
			mbus_txdata <= `SD {mbus_txdata[23:0], tx_char[7:0]};
		end
		if(shift_in_txaddr) begin
			mbus_txaddr <= `SD {mbus_txaddr[23:0], tx_char[7:0]};
		end
		mbus_txpend <= `SD mbus_txpend_next;
		mbus_txreq <= `SD mbus_txreq_next;
		mbus_txresp_ack <= `SD mbus_txsucc | mbus_txfail;
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
	mbus_txpend_next = 1'b0;
	mbus_txreq_next = 1'b0;
	shift_in_txaddr = 1'b0;
	shift_in_txdata = 1'b0;
	ackgen_generate_nak = 1'b0;
	ackgen_generate_ack = 1'b0;
	case(state)
		STATE_IDLE: begin
			reset_status = 1'b1;
			if(rxreq)
				next_state = STATE_HDR0;
			else if(rxfail)
				next_state = STATE_FAIL_ACK;
			else if(hd_header_done) //TODO: There should be no instance in which there is an empty MBus message, correct?
				next_state = STATE_TX_START;
		end
		
		STATE_HDR0: begin
			rx_frame_valid = 1'b1;
			send_flag = 1'b1;
			next_state = STATE_HDR1;
		end
		
		STATE_HDR1: begin
			rx_frame_valid = 1'b1;
			send_ctr = 1'b1;
			if(state_ctr[0]) begin
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

		//MBus TX states...
		STATE_TX_START: begin //0x9
			if(~hd_frame_valid) begin
				next_state = STATE_TX_END0;
			end else if(shift_count == 4'd4) begin
				next_state = STATE_TX_DATA;
			end else if(tx_char_valid) begin
				shift_in_txaddr = 1'b1;
			end
		end

		STATE_TX_DATA: begin //0xa
			shift_in_txdata = tx_char_valid;
			if(tx_char_valid) begin
				if(tx_char[8] && hd_is_fragment) begin
					hd_header_done_clear = 1'b1;
					ackgen_generate_ack = 1'b1;
					next_state = STATE_TX_FRAGMENT;
				end else begin
					if(shift_count == 4'd3)
						next_state = STATE_TX_WAIT_PEND;
				end
			end
			if(~hd_frame_valid)
				next_state = STATE_TX_END0;
		end

		STATE_TX_WAIT_PEND: begin //0xb
            //ANDREW: multi-word transmissions must wait until 
            // txack goes low from last tx and 
            // mbus_txack runs on mbus_clk, not clk
            if (~mbus_txack)  
                next_state = STATE_TX_WORD1;
		end

		STATE_TX_WORD1: begin //d
			mbus_txreq_next = 1'b1;
			mbus_txpend_next = hd_frame_valid;
			if(mbus_txack) 
				next_state = STATE_TX_DATA;
		end

		STATE_TX_FRAGMENT: begin //e
			if(~ack_message_frame_valid & hd_frame_valid) begin
				next_state = STATE_TX_DATA;
			end
		end

		STATE_TX_END0: begin // f
			hd_header_done_clear = 1'b1;
			if(mbus_txfail) begin
				ackgen_generate_nak = 1'b1;
				next_state = STATE_TX_END1;
			end else if(mbus_txsucc) begin
				ackgen_generate_ack = 1'b1;
				next_state = STATE_TX_END1;
			end
		end
		
		STATE_TX_END1: begin
			if(ack_message_frame_valid == 1'b0)
				next_state = STATE_IDLE;
		end
	endcase
end


endmodule
