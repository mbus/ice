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

`ifdef POWER_GATING
`undef POWER_GATING
`endif

module mbus_general_layer_wrapper(
	input 	CLK_EXT,
	input	MASTER_EN,
	input	mbus_snoop_enabled,
	input	[19:0] ADDRESS,
	input	[`DYNA_WIDTH-1:0] ASSIGNED_ADDR_IN,
	output	[`DYNA_WIDTH-1:0] ASSIGNED_ADDR_OUT,
	input	ASSIGNED_ADDR_VALID,
	output	ASSIGNED_ADDR_WRITE,
	output	ASSIGNED_ADDR_INVALIDn,
	input 	CLKIN,          // MBUS Clock input
	output	CLKOUT,         // MBUS clock output
	input 	RESETn,
	input 	DIN,            // MBUS Data In
	output 	DOUT,           // MBUS Data out
	input	[`ADDR_WIDTH-1:0] TX_ADDR,  // MBUS address to send data to
	input 	[`DATA_WIDTH-1:0] TX_DATA,  // Data to send over MBUS (1 Word)
	input 	TX_PEND,        // Raise high to to start transmit data
	input 	TX_REQ,         // Raise high at start of transmit to send data with >1 Word
	input 	TX_PRIORITY,    // No Idea, yet!
    output 	TX_ACK,         // High when TX data latched, 
                            // lower and re-raise TX_REQ for additional bytes
                            // Lower TX_PEND for last byte transmitted
	output 	[`ADDR_WIDTH-1:0] RX_ADDR,  // MBUS address of recived message (ours or broadcast?) 
	output 	[`DATA_WIDTH-1:0] RX_DATA,  // MBUS recieved data (1 Word/time)
	output 	RX_REQ,         // MBUS will raise to indidicate an RX'ed packet
	input 	RX_ACK,         // Raise to tell MBUS you got it
	output  RX_BROADCAST,
	output	RX_FAIL,
	output 	RX_PEND,        // MBUS will raise for more data coming over RX 
	output	[1:0] ice_export_control_bits,
	output 	TX_FAIL, 
	output 	TX_SUCC, 
	input 	TX_RESP_ACK

	`ifdef POWER_GATING
	// power gated signals from sleep controller
	input 	MBC_RESET,
	// power gated signals to layer controller
	output 	LRC_SLEEP,
	output 	LRC_CLKENB,
	output 	LRC_RESET,
	output 	LRC_ISOLATE,
	// wake up bus controller
	input 	EXTERNAL_INT,
	output	CLR_EXT_INT,
	output	CLR_BUSY,
	// wake up processor
	output	reg SLEEP_REQUEST_TO_SLEEP_CTRL,
	`endif
);
parameter THRESHOLD = 20'h05fff;

wire	CLK_CTRL_TO_NODE;
wire	DOUT_CTRL_TO_NODE;
wire	NODE_RX_REQ;
wire	NODE_RX_ACK;
`ifdef POWER_GATING
wire	SLEEP_REQ;
`endif
reg		ctrl_addr_match, ctrl_rx_ack;

`ifdef POWER_GATING
wire 	RESETn_local = (RESETn & (~MBC_RESET) & MASTER_EN);
`else
wire 	RESETn_local = RESETn & MASTER_EN;
`endif

wire dout_from_bus, clkout_from_bus;

wire clkin = (MASTER_EN==1'b1)? CLK_CTRL_TO_NODE : CLKIN;
wire din = (MASTER_EN==1'b1)? DOUT_CTRL_TO_NODE : DIN;

always @ *
begin
	if ((RX_BROADCAST) &&  (RX_ADDR[`FUNC_WIDTH-1:0]==`CHANNEL_CTRL))
		ctrl_addr_match = 1;
	else
		ctrl_addr_match = 0;
end

assign RX_REQ = (ctrl_addr_match & MASTER_EN)? 1'b0 : NODE_RX_REQ;

always @ (posedge CLK_EXT or negedge RESETn_local)
begin
	if (~RESETn_local)
	begin
		ctrl_rx_ack <= 0;
		`ifdef POWER_GATING
		SLEEP_REQUEST_TO_SLEEP_CTRL <= 0;
		`endif
	end
	else
	begin
		if (ctrl_addr_match & NODE_RX_REQ)
		begin
			ctrl_rx_ack <= 1;
		end

		if (ctrl_rx_ack & (~NODE_RX_REQ))
			ctrl_rx_ack <= 0;

		`ifdef POWER_GATING
		// delay 1 cycle
		SLEEP_REQUEST_TO_SLEEP_CTRL <= SLEEP_REQ;
		`endif
	end
end

assign NODE_RX_ACK = (RX_ACK | ctrl_rx_ack);

mbus_ctrl ctrl0(
	.CLK_EXT(CLK_EXT),
	.RESETn(RESETn_local),
	.CLKIN(CLKIN),
	.CLKOUT(CLK_CTRL_TO_NODE),
	.DIN(DIN),
	.DOUT(DOUT_CTRL_TO_NODE),
	.THRESHOLD(THRESHOLD)
);

mbus_node node0(
	.CLKIN(clkin), 
	.RESETn(RESETn), 
	.DIN(din), 
	.CLKOUT(clkout_from_bus),
	.DOUT(dout_from_bus), 
	.TX_ADDR(TX_ADDR), 
	.TX_DATA(TX_DATA), 
	.TX_PEND(TX_PEND), 
	.TX_REQ(TX_REQ), 
	.TX_PRIORITY(TX_PRIORITY),
	.TX_ACK(TX_ACK), 
	.RX_ADDR(RX_ADDR), 
	.RX_DATA(RX_DATA), 
	.RX_REQ(NODE_RX_REQ), 
	.RX_ACK(NODE_RX_ACK), 
	.RX_BROADCAST(RX_BROADCAST),
	.RX_FAIL(RX_FAIL),
	.RX_PEND(RX_PEND), 
	.ice_export_control_bits(ice_export_control_bits),
	.TX_FAIL(TX_FAIL), 
	.TX_SUCC(TX_SUCC), 
	.TX_RESP_ACK(TX_RESP_ACK),
	`ifdef POWER_GATING
	.MBC_RESET(MBC_RESET),
	.LRC_SLEEP(LRC_SLEEP),
	.LRC_CLKENB(LRC_CLKENB),
	.LRC_RESET(LRC_RESET),
	.LRC_ISOLATE(LRC_ISOLATE),
	.SLEEP_REQUEST_TO_SLEEP_CTRL(SLEEP_REQ),
	.EXTERNAL_INT(EXTERNAL_INT),
	.CLR_EXT_INT(CLR_EXT_INT),
	.CLR_BUSY(CLR_BUSY),
	`endif
	.ASSIGNED_ADDR_IN(ASSIGNED_ADDR_IN),
	.ASSIGNED_ADDR_OUT(ASSIGNED_ADDR_OUT),
	.ASSIGNED_ADDR_VALID(ASSIGNED_ADDR_VALID),
	.ASSIGNED_ADDR_WRITE(ASSIGNED_ADDR_WRITE),
	.ASSIGNED_ADDR_INVALIDn(ASSIGNED_ADDR_INVALIDn),
	.MASTER_EN(MASTER_EN),
	.mbus_snoop_enabled(mbus_snoop_enabled),
	.ADDRESS(ADDRESS)
);

mbus_wire_ctrl wc0(
	.RESETn(RESETn), 
	.DOUT_FROM_BUS(dout_from_bus), 
	.CLKOUT_FROM_BUS(clkout_from_bus),
	.DOUT(DOUT), 
	.CLKOUT(CLKOUT)
);

endmodule
