`define STATE_RESET 0
`define STATE_START_TX 1
`define STATE_TX_ECI_NEG 2
`define STATE_TX_ECI_POS 3

module ein_mod(
	input clk,
	input resetn,
	input [7:0] fifo_din,
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

assign fifo_RE = bit_ctr_incr && (bit_ctr == 3'd7);

always @(posedge clk) begin
	if(~resetn) begin
		state <= #1 `STATE_RESET;
		state_ctr <= #1 0;
		bit_ctr <= #1 3'd0;
		EMO_OUT <= #1 1'b0;
		EDI_OUT <= #1 1'b0;
		ECI_OUT <= #1 1'b0;
	end else begin
		state <= #1 next_state;
		EMO_OUT <= #1 next_emo_out;
		EDI_OUT <= #1 next_edi_out;
		ECI_OUT <= #1 next_eci_out;
		if(next_state != state)
			state_ctr <= #1 0;
		else
			state_ctr <= #1 state_ctr + 1;
		if(bit_ctr_incr)
			bit_ctr <= #1 bit_ctr + 1;
	end
end

always @* begin
	next_state = state;
	next_emo_out = 1'b1;
	next_edi_out = 1'b0;
	next_eci_out = 1'b0;
	bit_ctr_incr = 1'b0;
	case(state)
		`STATE_RESET: begin
			next_emo_out = 1'b0;
			if(start_tx) 
				next_state = `STATE_START_TX;
		end

		`STATE_START_TX: begin
			if(state_ctr == CLK_DIV-1)
				next_state = `STATE_TX_ECI_NEG;
		end

		`STATE_TX_ECI_NEG: begin
			next_edi_out = fifo_din[bit_ctr];
			if(state_ctr == CLK_DIV-1)
				next_state = `STATE_TX_ECI_POS;
		end

		`STATE_TX_ECI_POS: begin
			next_eci_out = 1'b1;
			next_edi_out = fifo_din[bit_ctr];
			if(state_ctr == CLK_DIV-1) begin
				bit_ctr_incr = 1'b1;
				if(fifo_empty)
					next_state = `STATE_RESET;
				else
					next_state = `STATE_TX_ECI_NEG;
			end
		end
	endcase
end

endmodule

