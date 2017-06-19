/*
 * MBus Copyright 2015 Regents of the University of Michigan
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`include "include/mbus_def.v"

module mbus_layer_wrapper(
	input 	CLKIN, 
	input 	RESETn, 
	input 	DIN, 
	output 	CLKOUT,
	output 	DOUT, 
	input 	[`ADDR_WIDTH-1:0] TX_ADDR, 
	input 	[`DATA_WIDTH-1:0] TX_DATA, 
	input 	TX_PEND, 
	input 	TX_REQ, 
	input 	TX_PRIORITY,
	output 	TX_ACK, 
	output 	[`ADDR_WIDTH-1:0] RX_ADDR, 
	output 	[`DATA_WIDTH-1:0] RX_DATA, 
	output 	RX_REQ, 
	input 	RX_ACK, 
	output	RX_BROADCAST,
	output 	RX_FAIL,
	output 	RX_PEND, 
	output 	TX_FAIL, 
	output 	TX_SUCC, 
	input 	TX_RESP_ACK,

	output 	LC_POWER_ON,
	output 	LC_RELEASE_CLK,
	output 	LC_RELEASE_RST,
	output 	LC_RELEASE_ISO,

	input 	REQ_INT,

	output	[`DYNA_WIDTH-1:0] PREFIX_ADDR_OUT
);

parameter ADDRESS = 20'h12345;

//wire	n0_power_on, n0_sleep_req, n0_release_rst, n0_release_iso_from_sc;
wire	mbc_sleep, mbc_isolate, mbc_reset, mbc_sleep_req;
wire	ext_int_to_bus, ext_int_to_wire, clr_ext_int, clr_busy; 
wire	w_n0lc0, w_n0lc0_clk_out;

reg		[`ADDR_WIDTH-1:0] n0_rx_addr_f_bc;
reg		[`DATA_WIDTH-1:0] n0_rx_data_f_bc;
reg		n0_tx_ack_f_bc, n0_rx_req_f_bc, n0_rx_bcast_f_bc, n0_rx_fail_f_bc, n0_rx_pend_f_bc, n0_tx_fail_f_bc, n0_tx_succ_f_bc;
//reg	n0_pwr_on_f_bc, n0_rel_clk_f_bc, n0_rel_rst_f_bc, n0_rel_iso_f_bc;
reg		m0_lrc_sleep_f_bc, m0_lrc_clkenb_f_bc, m0_lrc_reset_f_bc, m0_lrc_isolate_f_bc;

wire	[`ADDR_WIDTH-1:0] n0_rx_addr_t_iso;
wire	[`DATA_WIDTH-1:0] n0_rx_data_t_iso;
wire	n0_tx_ack_t_iso, n0_rx_req_t_iso, n0_rx_bcast_t_iso, n0_rx_fail_t_iso, n0_rx_pend_t_iso, n0_tx_fail_t_iso, n0_tx_succ_t_iso;
//wire	n0_pwr_on_t_iso, n0_rel_clk_t_iso, n0_rel_rst_t_iso, n0_rel_iso_t_iso;
wire	m0_lrc_sleep_t_iso, m0_lrc_clkenb_t_iso, m0_lrc_reset_t_iso, m0_lrc_isolate_t_iso;

reg		[`ADDR_WIDTH-1:0] n0_tx_addr_f_lc;
reg		[`DATA_WIDTH-1:0] n0_tx_data_f_lc;
reg		n0_tx_req_f_lc, n0_tx_pend_f_lc, n0_priority_f_lc, n0_rx_ack_f_lc, n0_tx_resp_ack_f_lc;

wire	[`ADDR_WIDTH-1:0] n0_tx_addr_t_bc;
wire	[`DATA_WIDTH-1:0] n0_tx_data_t_bc;
wire	n0_tx_req_t_bc, n0_tx_pend_t_bc, n0_priority_t_bc, n0_rx_ack_t_bc, n0_tx_resp_ack_t_bc;

wire	[`DYNA_WIDTH-1:0] rf_addr_out_to_node, rf_addr_in_from_node;
wire	rf_addr_valid, rf_addr_write, rf_addr_rstn;

wire	sleep_ctrl_clr_busy;

assign PREFIX_ADDR_OUT = rf_addr_out_to_node;
   
// always on block, interface with layer controller
mbus_regular_isolation iso0
	(.RELEASE_ISO_FROM_SLEEP_CTRL(mbc_isolate),
	 .TX_ADDR_FROM_LC(n0_tx_addr_f_lc), .TX_DATA_FROM_LC(n0_tx_data_f_lc), .TX_REQ_FROM_LC(n0_tx_req_f_lc), .TX_ACK_TO_LC(TX_ACK), .TX_PEND_FROM_LC(n0_tx_pend_f_lc), .PRIORITY_FROM_LC(n0_priority_f_lc),
	 .RX_ADDR_TO_LC(RX_ADDR), .RX_DATA_TO_LC(RX_DATA), .RX_REQ_TO_LC(RX_REQ), .RX_ACK_FROM_LC(n0_rx_ack_f_lc), .RX_FAIL_TO_LC(RX_FAIL), .RX_PEND_TO_LC(RX_PEND), 
	 .TX_SUCC_TO_LC(TX_SUCC), .TX_FAIL_TO_LC(TX_FAIL), .TX_RESP_ACK_FROM_LC(n0_tx_resp_ack_f_lc), .RX_BROADCAST_TO_LC(RX_BROADCAST),

	 .TX_ADDR_TO_BC(n0_tx_addr_t_bc), .TX_DATA_TO_BC(n0_tx_data_t_bc), .TX_REQ_TO_BC(n0_tx_req_t_bc), .TX_ACK_FROM_BC(n0_tx_ack_f_bc), .TX_PEND_TO_BC(n0_tx_pend_t_bc), .PRIORITY_TO_BC(n0_priority_t_bc),
	 .RX_ADDR_FROM_BC(n0_rx_addr_f_bc), .RX_DATA_FROM_BC(n0_rx_data_f_bc), .RX_REQ_FROM_BC(n0_rx_req_f_bc), .RX_ACK_TO_BC(n0_rx_ack_t_bc), .RX_FAIL_FROM_BC(n0_rx_fail_f_bc), .RX_PEND_FROM_BC(n0_rx_pend_f_bc), 
	 .TX_FAIL_FROM_BC(n0_tx_fail_f_bc), .TX_SUCC_FROM_BC(n0_tx_succ_f_bc), .TX_RESP_ACK_TO_BC(n0_tx_resp_ack_t_bc), .RX_BROADCAST_FROM_BC(n0_rx_bcast_f_bc),

	 .POWER_ON_FROM_BC(m0_lrc_sleep_f_bc), .RELEASE_CLK_FROM_BC(m0_lrc_clkenb_f_bc), .RELEASE_RST_FROM_BC(m0_lrc_reset_f_bc), .RELEASE_ISO_FROM_BC(m0_lrc_isolate_f_bc), .RELEASE_ISO_FROM_BC_MASKED(LC_RELEASE_ISO),
	 .POWER_ON_TO_LC(LC_POWER_ON), .RELEASE_CLK_TO_LC(LC_RELEASE_CLK), .RELEASE_RST_TO_LC(LC_RELEASE_RST));

// power gated block
mbus_node#(.ADDRESS(ADDRESS)) n0
     (.CLKIN(CLKIN), .CLKOUT(w_n0lc0_clk_out), .RESETn(RESETn), .DIN(DIN), .DOUT(w_n0lc0), 
      .TX_ADDR(n0_tx_addr_t_bc), .TX_DATA(n0_tx_data_t_bc), .TX_REQ(n0_tx_req_t_bc), .TX_ACK(n0_tx_ack_t_iso), .TX_PEND(n0_tx_pend_t_bc), .TX_PRIORITY(n0_priority_t_bc),
      .RX_ADDR(n0_rx_addr_t_iso), .RX_DATA(n0_rx_data_t_iso), .RX_REQ(n0_rx_req_t_iso), .RX_ACK(n0_rx_ack_t_bc), .RX_BROADCAST(n0_rx_bcast_t_iso), .RX_FAIL(n0_rx_fail_t_iso), .RX_PEND(n0_rx_pend_t_iso),
      .TX_SUCC(n0_tx_succ_t_iso), .TX_FAIL(n0_tx_fail_t_iso), .TX_RESP_ACK(n0_tx_resp_ack_t_bc),
	  .MBC_RESET(mbc_reset), .SLEEP_REQUEST_TO_SLEEP_CTRL(mbc_sleep_req), 
	  .LRC_SLEEP(m0_lrc_sleep_t_iso), .LRC_CLKENB(m0_lrc_clkenb_t_iso), .LRC_RESET(m0_lrc_reset_t_iso), .LRC_ISOLATE(m0_lrc_isolate_t_iso),
	  .EXTERNAL_INT(ext_int_to_bus), .CLR_EXT_INT(clr_ext_int), .CLR_BUSY(clr_busy),
	  .ASSIGNED_ADDR_IN(rf_addr_out_to_node), .ASSIGNED_ADDR_OUT(rf_addr_in_from_node), 
	  .ASSIGNED_ADDR_VALID(rf_addr_valid), .ASSIGNED_ADDR_WRITE(rf_addr_write), .ASSIGNED_ADDR_INVALIDn(rf_addr_rstn));


//mbus_regular_sleep_ctrl sc0
//	(.CLKIN(CLKIN), .RESETn(RESETn), .SLEEP_REQ(mbc_sleep_req), 
//	 .POWER_ON(mbc_sleep), .RELEASE_CLK(), .RELEASE_ISO(mbc_isolate), .BC_PG_CLR_BUSY(sleep_ctrl_clr_busy),
//	.RELEASE_RST(mbc_reset));

//always on block
mbus_regular_sleep_ctrl sc0
	(.MBUS_CLKIN(CLKIN), .RESETn(RESETn), .SLEEP_REQ(mbc_sleep_req), 
	 .MBC_SLEEP(mbc_sleep), .MBC_SLEEP_B(), .MBC_ISOLATE(mbc_isolate), .MBC_ISOLATE_B(),
	 .MBC_CLK_EN(), .MBC_CLK_EN_B(), .MBC_RESET(mbc_reset), .MBC_RESET_B(), .INT_CLR_BUSY(sleep_ctrl_clr_busy));
	//.POWER_ON(mbc_sleep), .RELEASE_CLK(), .RELEASE_RST(mbc_reset), .RELEASE_ISO(mbc_isolate), .BC_PG_CLR_BUSY(sleep_ctrl_clr_busy));

// always on wire controller
mbus_wire_ctrl lc0
	(.RESETn(RESETn), .DIN(DIN), .CLKIN(CLKIN), 										// the same input as the node
	 .RELEASE_ISO_FROM_SLEEP_CTRL(mbc_isolate),			// from sleep controller
	 .DOUT_FROM_BUS(w_n0lc0), .CLKOUT_FROM_BUS(w_n0lc0_clk_out), 	// the outputs from the node
	 .DOUT(DOUT), .CLKOUT(CLKOUT),									// to next node
	 .EXTERNAL_INT(ext_int_to_wire));

// always on register files
mbus_addr_rf rf0(
	.RESETn							(RESETn),
	.RELEASE_ISO_FROM_SLEEP_CTRL	(mbc_isolate),
	.ADDR_OUT						(rf_addr_out_to_node),
	.ADDR_IN						(rf_addr_in_from_node),
	.ADDR_VALID						(rf_addr_valid),
	.ADDR_WR_EN						(rf_addr_write),
	.ADDR_CLRn						(rf_addr_rstn)
);

// always on interrupt controller
mbus_int_ctrl mic0(
	.CLKIN					(CLKIN),
	.RESETn					(RESETn),
	.MBC_ISOLATE			(mbc_isolate),
//	.SC_CLR_BUSY			(mbc_sleep),
	.SC_CLR_BUSY			(sleep_ctrl_clr_busy),
	.MBUS_CLR_BUSY			(clr_busy),

	.REQ_INT				(REQ_INT), 
	.MBC_SLEEP				(mbc_sleep),
	.LRC_SLEEP				(LC_POWER_ON),
	.EXTERNAL_INT_TO_WIRE	(ext_int_to_wire), 
	.EXTERNAL_INT_TO_BUS	(ext_int_to_bus), 
	.CLR_EXT_INT			(clr_ext_int)
);

always @ *
begin
	if (mbc_sleep)
	begin
		n0_tx_ack_f_bc		= 1'bx;
		n0_rx_addr_f_bc		= 32'hxxxxxxxx;
		n0_rx_data_f_bc		= 32'hxxxxxxxx;
		n0_rx_req_f_bc		= 1'bx;
		n0_rx_bcast_f_bc	= 1'bx;
		n0_rx_fail_f_bc		= 1'bx;
		n0_rx_pend_f_bc		= 1'bx;
		n0_tx_fail_f_bc		= 1'bx;
		n0_tx_succ_f_bc		= 1'bx;
		m0_lrc_sleep_f_bc	= 1'bx;
		m0_lrc_clkenb_f_bc	= 1'bx;
		m0_lrc_reset_f_bc	= 1'bx;
		m0_lrc_isolate_f_bc	= 1'bx;
	end
	else
	begin
		n0_tx_ack_f_bc		= n0_tx_ack_t_iso;
		n0_rx_addr_f_bc		= n0_rx_addr_t_iso;
		n0_rx_data_f_bc		= n0_rx_data_t_iso;
		n0_rx_req_f_bc		= n0_rx_req_t_iso;
		n0_rx_bcast_f_bc	= n0_rx_bcast_t_iso;
		n0_rx_fail_f_bc		= n0_rx_fail_t_iso;
		n0_rx_pend_f_bc		= n0_rx_pend_t_iso;
		n0_tx_fail_f_bc		= n0_tx_fail_t_iso;
		n0_tx_succ_f_bc		= n0_tx_succ_t_iso;
		m0_lrc_sleep_f_bc	= m0_lrc_sleep_t_iso;
		m0_lrc_clkenb_f_bc	= m0_lrc_clkenb_t_iso;
		m0_lrc_reset_f_bc	= m0_lrc_reset_t_iso;
		m0_lrc_isolate_f_bc	= m0_lrc_isolate_t_iso;
	end
end

always @ *
begin
	// layer controller is power off
	if (LC_POWER_ON)
	begin
		n0_tx_addr_f_lc 	= 32'hxxxxxxxx;
		n0_tx_data_f_lc 	= 32'hxxxxxxxx;
		n0_tx_req_f_lc 		= 1'bx;
		n0_tx_pend_f_lc 	= 1'bx;
		n0_priority_f_lc 	= 1'bx;
		n0_rx_ack_f_lc 		= 1'bx;
		n0_tx_resp_ack_f_lc = 1'bx;
	end
	else
	begin
		n0_tx_addr_f_lc 	= TX_ADDR;
		n0_tx_data_f_lc 	= TX_DATA;
		n0_tx_req_f_lc 		= TX_REQ;
		n0_tx_pend_f_lc 	= TX_PEND;
		n0_priority_f_lc 	= TX_PRIORITY;
		n0_rx_ack_f_lc 		= RX_ACK;
		n0_tx_resp_ack_f_lc = TX_RESP_ACK;
	end
end


endmodule
