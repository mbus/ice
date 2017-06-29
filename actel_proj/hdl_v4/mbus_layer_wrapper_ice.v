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
	input mbus_tx_prio, //not implimented

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
	output      global_counter_inc,
	
	output [3:0] debug
);

assign debug = 4'h0;

    //
    // MBUS TX SIGNALS
    //

    //bus interface stuff
    wire            tx_frame_valid;
    wire            tx_char_valid;
    wire [7:0]      tx_char;
    wire            tx_char_pending;
    wire            tx_char_advance;

    //mbus transmit stuff
    wire [31:0]     tx_mbus_txaddr;
    wire [31:0]     tx_mbus_txdata;
    wire            tx_mbus_txreq;
    wire            tx_mbus_txpend;
    wire            tx_mbus_txack_async;
    wire            tx_mbus_txack_dl;
    wire            tx_mbus_txfail_async;
    wire            tx_mbus_txfail_dl;
    wire            tx_mbus_txsucc_async;
    wire            tx_mbus_txsucc_dl;
    wire            tx_mbus_txresp_ack;
 
    wire            tx_gen_ack;
    wire            tx_gen_nak;
    wire            tx_acknak_valid;


    //
    // TX ACK/NAK output signals
    //
    wire [7:0] ack_message_data;
    wire ack_message_data_valid;
    wire ack_message_frame_valid;

    //
    // MBUS RX SIGNALS
    //
    //stuff from mbus  
    wire [31:0]         rx_mbus_rx_addr;
	wire [31:0]         rx_mbus_rx_data;
	wire                rx_mbus_rx_req_async; 
	wire                rx_mbus_rx_req_dl; 
	wire                rx_mbus_rx_ack;
	wire                rx_mbus_rx_broadcast;
	wire                rx_mbus_rx_fail_async;
    wire                rx_mbus_rx_fail_dl;
	wire                rx_mbus_rx_pend_async;
	wire                rx_mbus_rx_pend_dl;
	wire [1:0]          rx_mbus_rx_control_bits;
    
    wire                rx_buffer_request;
    wire                rx_buffer_grant;
    wire [7:0]          rx_buffer_data;
    wire                rx_buffer_valid;


wire hd_frame_valid, hd_frame_data_valid, hd_header_done, hd_is_fragment, hd_is_empty;
wire [8:0] hd_frame_tail, hd_frame_addr;
wire hd_frame_latch_tail;
wire [7:0] hd_header_eid;
wire hd_frame_next; // = shift_in_txaddr | shift_in_txdata;
wire [8:0] hd_frame_data;


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
	.in_frame_data(hd_frame_data),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_valid(hd_frame_data_valid),
	.in_frame_tail(hd_frame_tail),
	.in_frame_addr(hd_frame_addr),
	.in_frame_latch_tail(hd_frame_latch_tail),
	.out_frame_data(rx_buffer_data),
	.out_frame_valid(rx_buffer_request),
	.out_frame_data_latch(rx_buffer_valid)
);

/**********
*  I have no idea how this works
*****/
header_decoder hd0(
	.clk(clk),
	.rst(reset),
	.in_frame_data(hd_frame_data),
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
	.header_done_clear(1'h0)
);





// MBUS TX DRIVER
//
// handles all the HOST->ICE->MBUS traffic signals
//

assign tx_frame_valid =  hd_header_done;
assign tx_char_valid = hd_frame_data_valid & hd_header_done & ~hd_frame_data[8];
assign tx_char =  hd_frame_data[7:0];
assign tx_char_pending = hd_frame_valid & ~hd_frame_data[8];
assign tx_acknak_valid = ack_message_frame_valid;

assign hd_frame_next = tx_char_advance;

mbus_ice_driver_tx tx0 (
    .clk(clk),
    .reset(reset),

    //bus interface stuff
    .tx_frame_valid(tx_frame_valid),
    .tx_char_valid(tx_char_valid),
    .tx_char(tx_char),
    .tx_char_pending(tx_char_pending),
    .tx_char_advance(tx_char_advance),

    //mbus transmit stuff
    .tx_mbus_txaddr(tx_mbus_txaddr),
    .tx_mbus_txdata(tx_mbus_txdata),
    .tx_mbus_txreq(tx_mbus_txreq),
    .tx_mbus_txpend(tx_mbus_txpend),
    .tx_mbus_txack(tx_mbus_txack_dl),
    .tx_mbus_txfail(tx_mbus_txfail_dl),
    .tx_mbus_txsucc(tx_mbus_txsucc_dl),
    .tx_mbus_txresp_ack(tx_mbus_txresp_ack),

    .tx_gen_ack(tx_gen_ack),
    .tx_gen_nak(tx_gen_nak),
    .tx_acknak_valid(tx_acknak_valid)
    );


// MBUS RX DRIVER
//
// handles all the MBUS->ICE->HOST traffic signals
//

assign rx_buffer_grant = rx_buffer_request;

mbus_ice_driver_rx rx0(
    .clk(clk),
    .reset(reset),

    //stuff from mbus  
    .mbus_rx_addr(rx_mbus_rx_addr),
    .mbus_rx_data(rx_mbus_rx_data),
    .mbus_rx_req(rx_mbus_rx_req_dl), 
    .mbus_rx_ack(rx_mbus_rx_ack),
    .mbus_rx_broadcast(rx_mbus_rx_broadcast),
    .mbus_rx_fail(rx_mbus_rx_fail_dl),
    .mbus_rx_pend(rx_mbus_rx_pend_dl),
    .mbus_rx_control_bits(rx_mbus_rx_control_bits),
    
    .buffer_request(rx_buffer_request),
    .buffer_grant(rx_buffer_grant),
    .buffer_data(rx_buffer_data),
    .buffer_valid(rx_buffer_valid),

    .global_counter(global_counter),
    .global_counter_inc(global_counter_inc)
    );



/************************************************************
 *Ack generator is used to easily create ACK & NAK sequences*
 ************************************************************/
ack_generator ag0(
	.clk(clk),
	.reset(reset),
	
	.generate_ack(tx_gen_ack),
	.generate_nak(tx_gen_nak),
	.eid_in(hd_header_eid),
	
	.message_data(ack_message_data),
	.message_data_valid(ack_message_data_valid),
	.message_frame_valid(ack_message_frame_valid)
);

//Only using an output message fifo here because we should be able to keep up with requests in real-time
wire [8:0] mf_sl_data;
wire [8:0] mf_sl_tail;
reg [7:0] message_idx;
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
    .RX_ADDR(rx_mbus_rx_addr),
    .RX_DATA(rx_mbus_rx_data),
    .RX_REQ(rx_mbus_rx_req_async),
    .RX_ACK(rx_mbus_rx_ack),
    .RX_BROADCAST(rx_mbus_rx_broadcast),
    .RX_FAIL(rx_mbus_rx_fail_async),
    .RX_PEND(rx_mbus_rx_pend_async),
    .ice_export_control_bits(rx_mbus_rx_control_bits), 

    //TX Ports
    .TX_ADDR(tx_mbus_txaddr),
    .TX_DATA(tx_mbus_txdata),
    .TX_PEND(tx_mbus_txpend),
    .TX_REQ(tx_mbus_txreq),
    .TX_PRIORITY(1'h0),
    .TX_ACK(tx_mbus_txack_async),
    .TX_FAIL(tx_mbus_txfail_async), 
    .TX_SUCC(tx_mbus_txsucc_async),
    .TX_RESP_ACK(tx_mbus_txresp_ack)
);


/* 
 *  a bunch of double latches to jump clock domains
 *  from several control signals coming from MBUS
 */

double_latch dl_TX_ACK(
    .clk(clk),
    .reset (reset),
    .async(tx_mbus_txack_async),
    .dlatched(tx_mbus_txack_dl)
    );

double_latch dl_TX_FAIL(
    .clk(clk),
    .reset (reset),
    .async(tx_mbus_txfail_async),
    .dlatched(tx_mbus_txfail_dl)
    );

double_latch dl_TX_SUCC(
    .clk(clk),
    .reset (reset),
    .async(tx_mbus_txsucc_async), 
    .dlatched(tx_mbus_txsucc_dl)
    );

double_latch dl_RX_REQ(
    .clk(clk),
    .reset (reset),
    .async(rx_mbus_rx_req_async),
    .dlatched(rx_mbus_rx_req_dl)
    );

double_latch dl_RX_PEND(
    .clk(clk),
    .reset (reset),
    .async(rx_mbus_rx_pend_async),
    .dlatched(rx_mbus_rx_pend_dl)
    );

double_latch dl_RX_FAIL(
    .clk(clk),
    .reset (reset),
    .async(rx_mbus_rx_fail_async),
    .dlatched(rx_mbus_rx_fail_dl)
    );



endmodule
