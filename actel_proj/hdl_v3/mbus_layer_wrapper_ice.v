
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
	output reg incr_ctr
);

wire [31:0] mbus_rxaddr, mbus_txaddr;
wire [31:0] mbus_rxdata, mbus_txdata;

wire mbus_txpend, mbus_txreq, mbus_txack, mbus_txfail, mbus_txresp_ack, mbus_txsucc;
wire mbus_rxpend, mbus_rxreq, mbus_rxack, mbus_rxfail, mbus_rxbcast;
wire mbus_clk;
wire [15:0] mbus_clk_div;

/*mbus_clk_gen mbcg1(
	.sys_clk(clk),
	.reset(reset),
	.clk_div(mbus_clk_div),
	.mbus_clk(mbus_clk)
);*/

//Bus interface takes care of all buffering, etc for discrete data...
wire hd_data_valid, hd_frame_valid, hd_data_latch, hd_header_done, hd_is_fragment, hd_is_empty;
wire [7:0] hd_header_eid;
reg hd_header_done_clear;
reg send_flag, send_ctr;
wire [7:0] rx_frame_data = (send_flag) ? 8'h64 : (send_ctr) ? global_counter : rx_char;
wire [7:0] bi_debug;
wire rx_frame_data_latch = rx_char_latch | send_ctr;
bus_interface #(8'h64,1,1,1) bi0(
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
	.in_frame_data_latch(tx_data_latch | hd_data_latch),
	.out_frame_data(rx_frame_data),
	.out_frame_valid(rx_req),
	.out_frame_data_latch(rx_frame_data_latch),
	.debug(bi_debug)
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

 
mbus_layer_wrapper mclw1(
//    .CLK_EXT(mbus_clk),
    .RESETn(~reset),
    .CLKIN(CLKIN),
    .DIN(DIN),
    .CLKOUT(CLKOUT),
    .DOUT(DOUT),
    .TX_ADDR(mbus_txaddr),
    .TX_DATA(mbus_txdata),
    .TX_PEND(mbus_txpend),
    .TX_REQ(mbus_txreq),
    .TX_PRIORITY(1'b0),
    .TX_ACK(mbus_txack),
    .TX_FAIL(mbus_txfail),
    .TX_SUCC(mbus_txsucc),
    .TX_RESP_ACK(mbus_txresp_ack)
    .RX_ADDR(mbus_rxaddr),
    .RX_DATA(mbus_rxdata),
    .RX_REQ(mbus_rxreq),
    .RX_ACK(mbus_rxack),
    .RX_BROADCAST(mbus_rxbcast),
    .RX_FAIL(mbus_rxfail),
    .RX_PEND(mbus_rxpend),
   );


endmodule
