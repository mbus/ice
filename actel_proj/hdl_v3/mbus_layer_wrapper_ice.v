
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

mbus_clk_gen mbcg1(
	.sys_clk(clk),
	.reset(reset),
	.clk_div(mbus_clk_div),
	.mbus_clk(mbus_clk)
);
 
mbus_ctrl_layer_wrapper mclw1(
    .CLK_EXT(mbus_clk),
    .RESETn(~reset),
    .CLKIN(CLKIN),
    .DIN(DIN),
    .CLKOUT(CLKCOUT),
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
