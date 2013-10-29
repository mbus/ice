
`include "mbus_def_ice.v"

module mbus_layer_wrapper_ice(
	input 	RESETn, 

	input MASTER_NODE,
	input CPU_LAYER,
	input [19:0] ADDRESS,

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

	input 	[`ADDR_WIDTH-1:0] TX_ADDR, 
	input 	[`DATA_WIDTH-1:0] TX_DATA, 
	input 	TX_PEND, 
	input 	TX_REQ, 
	input 	TX_PRIORITY,
	output 	TX_ACK, 
	output 	TX_FAIL, 
	output 	TX_SUCC, 
	input 	TX_RESP_ACK,

	output 	[`ADDR_WIDTH-1:0] RX_ADDR, 
	output 	[`DATA_WIDTH-1:0] RX_DATA, 
	output 	RX_REQ, 
	input 	RX_ACK, 
	output	RX_BROADCAST,
	output 	RX_FAIL,
	output 	RX_PEND 
);

//wire	n0_power_on, n0_sleep_req, n0_release_rst, n0_release_iso_from_sc;
wire	ext_int_to_bus, ext_int_to_wire;
assign  ext_int_to_bus = 1'b0;
assign  ext_int_to_wire = 1'b0;
wire	w_n0lc0, w_n0lc0_clk_out;

wire	mbc_isolate;
assign	mbc_isolate = `IO_RELEASE;

wire	[`DYNA_WIDTH-1:0] rf_addr_out_to_node, rf_addr_in_from_node;
wire	rf_addr_valid, rf_addr_write, rf_addr_rstn;
   
// power gated block
mbus_node_ice n0(
	.CLKIN(CLKIN), .CLKOUT(w_n0lc0_clk_out), .RESETn(RESETn), .DIN(DIN), .DOUT(w_n0lc0), 
	.TX_ADDR(TX_ADDR), .TX_DATA(TX_DATA), .TX_REQ(TX_REQ), .TX_ACK(TX_ACK), .TX_PEND(TX_PEND), .TX_FAIL(TX_FAIL), .TX_PRIORITY(TX_PRIORITY),
	.RX_ADDR(RX_ADDR), .RX_DATA(RX_DATA), .RX_REQ(RX_REQ), .RX_ACK(RX_ACK), .RX_PEND(RX_PEND), .RX_FAIL(RX_FAIL), .RX_BROADCAST(RX_BROADCAST),
	.TX_SUCC(TX_SUCC), .TX_RESP_ACK(TX_RESP_ACK),
	.ASSIGNED_ADDR_IN(rf_addr_out_to_node), .ASSIGNED_ADDR_OUT(rf_addr_in_from_node), 
	.ASSIGNED_ADDR_VALID(rf_addr_valid), .ASSIGNED_ADDR_WRITE(rf_addr_write), .ASSIGNED_ADDR_INVALIDn(rf_addr_rstn),
	.ADDRESS(ADDRESS), .MASTER_NODE(MASTER_NODE), .CPU_LAYER(CPU_LAYER));

// always on wire controller
mbus_wire_ctrl_ice lc0
	(.RESETn(RESETn), .DIN(DIN), .CLKIN(CLKIN),			// the same input as the node
	 .RELEASE_ISO_FROM_SLEEP_CTRL(mbc_isolate),			// from sleep controller
	 .DOUT_FROM_BUS(w_n0lc0), .CLKOUT_FROM_BUS(w_n0lc0_clk_out), 	// the outputs from the node
	 .DOUT(DOUT), .CLKOUT(CLKOUT),					// to next node
	 .EXTERNAL_INT(ext_int_to_wire));

// always on register files
mbus_addr_rf_ice rf0(
	.RESETn	(RESETn),
	.RELEASE_ISO_FROM_SLEEP_CTRL(mbc_isolate),
	.ADDR_OUT(rf_addr_out_to_node),
	.ADDR_IN(rf_addr_in_from_node),
	.ADDR_VALID(rf_addr_valid),
	.ADDR_WR_EN(rf_addr_write),
	.ADDR_CLRn(rf_addr_rstn)
);

endmodule
