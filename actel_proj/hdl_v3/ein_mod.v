`include "include/ice_def.v"

`define STATE_RESET 0
`define STATE_START_TX 1
`define STATE_TX_ECI_NEG1 2
`define STATE_TX_ECI_NEG2 3
`define STATE_TX_ECI_POS1 4
`define STATE_TX_ECI_POS1_2 5
`define STATE_TX_ECI_POS2 6
`define STATE_FRAGMENT_WAIT 7

module ein_mod(
	input clk,
	input resetn,
	input [7:0] fifo_din,
	input fragment,
	output fifo_RE,
	input fifo_empty,
	input start_tx,
	output reg EMO_OUT,
	output reg EDI_OUT,
	output reg ECI_OUT
);

parameter CLK_DIV = 4000;
parameter CLK_DIV_LOG2 = 12;

reg [3:0] state, next_state;
reg [CLK_DIV_LOG2-1:0] state_ctr;
reg [2:0] bit_ctr;
reg next_emo_out;
reg next_edi_out;
reg next_eci_out;
reg bit_ctr_incr;
reg bit_ctr_reset;

assign fifo_RE = bit_ctr_incr && (bit_ctr == 3'd7);

always @(posedge clk) begin
	if(~resetn) begin
		state <= `SD `STATE_RESET;
		state_ctr <= `SD 0;
		bit_ctr <= `SD 3'd0;
		EMO_OUT <= `SD 1'b0;
		EDI_OUT <= `SD 1'b0;
		ECI_OUT <= `SD 1'b0;
	end else begin
		state <= `SD next_state;
		EMO_OUT <= `SD next_emo_out;
		EDI_OUT <= `SD next_edi_out;
		ECI_OUT <= `SD next_eci_out;
		if(next_state != state)
			state_ctr <= `SD 0;
		else
			state_ctr <= `SD state_ctr + 1;
		if(bit_ctr_reset)
			bit_ctr <= `SD 0;
		if(bit_ctr_incr)
			bit_ctr <= `SD bit_ctr + 1;
	end
end

always @* begin
	next_state = state;
	next_emo_out = 1'b1;
	next_edi_out = 1'b0;
	next_eci_out = 1'b0;
	bit_ctr_incr = 1'b0;
	bit_ctr_reset = 1'b0;
	case(state)
		`STATE_RESET: begin
			next_emo_out = 1'b0;
			if(start_tx) 
				next_state = `STATE_START_TX;
		end

		`STATE_START_TX: begin
			bit_ctr_reset = 1'b1;
			if(state_ctr == CLK_DIV-1)
				next_state = `STATE_TX_ECI_NEG1;
		end

		`STATE_TX_ECI_NEG1: begin
			if(goc_en) begin
				next_edi_out = 1'b1;
			end else begin
				next_edi_out = EDI_OUT;
			end
			if(state_ctr == CLK_DIV-1)
					next_state = `STATE_TX_ECI_NEG2;
		end
		
		`STATE_TX_ECI_NEG2: begin
			next_edi_out = fifo_din[bit_ctr];
			if(state_ctr == CLK_DIV-1)
				next_state = `STATE_TX_ECI_POS1;
		end

		`STATE_TX_ECI_POS1: begin
			next_eci_out = 1'b1;
			next_edi_out = fifo_din[bit_ctr];
			if(state_ctr == CLK_DIV-1) begin
				if(goc_en) begin
					next_state = `STATE_TX_ECI_POS1_2;
				else
					next_state = `STATE_TX_ECI_POS2;
			end
		end
		
		`STATE_TX_ECI_POS1_2: begin
			next_edi_out = fifo_din[bit_ctr];
			if(state_ctr == CLK_DIV-1) begin
				next_state = `STATE_TX_ECI_POS2;
			end
		end
		
		`STATE_TX_ECI_POS2: begin
			next_eci_out = 1'b1;
			next_edi_out = EDI_OUT;
			if(state_ctr == CLK_DIV-3) begin
				bit_ctr_incr = 1'b1;
			end else if(state_ctr == CLK_DIV-1) begin
				if(fifo_empty && fragment)
					next_state = `STATE_FRAGMENT_WAIT;
				else if(fifo_empty)
					next_state = `STATE_RESET;
				else
					next_state = `STATE_TX_ECI_NEG1;
			end
		end
		
		`STATE_FRAGMENT_WAIT: begin
			if(start_tx)
				next_state = `STATE_START_TX;
		end
	endcase
end

endmodule

