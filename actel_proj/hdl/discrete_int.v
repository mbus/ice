module discrete_int(
	input clk,
	input reset,

	input SDA_m,
	input SCL_m,

	output SDA_mpu,
	output SDA_mpd,
	output SDA_mp,
	output SCL_mpu,
	output SCL_mpd,
	output SCL_mp,

	input [7:0] tx_char,
	input tx_char_latch,
	input tx_req,

	output [7:0] rx_char,
	output rx_char_latch,
	output rx_req
);

parameter clock_div = 25;

//FIFO to queue up outgoing transmissions.  An extra bit to denote frame boundaries...
//NOTE: Make sure this doesn't overfill
wire [7:0] fifo_char;
wire fifo_valid;
wire fifo_req;
reg fifo_latch;
fifo #(9,256) f1(
	.clk(clk),
	.reset(reset),
	.in({tx_req, tx_char}),
	.in_latch(tx_char_latch | tx_req),
	.out({fifo_req, fifo_char}),
	.out_latch(fifo_latch),
	.out_valid(fifo_valid)
);

reg tx_req_clear;
reg cur_bit_decr;
reg cur_bit_reset;
reg [7:0] clock_counter;
reg [2:0] cur_bit;

//Defining states as parameters since `defines have global scope
parameter STATE_IDLE = 0;
parameter STATE_TX_START = 1;
parameter STATE_TX_SCL_LOW = 2;
parameter STATE_TX_SCL_HIGH = 3;
parameter STATE_TX_ACK_SCL_LOW = 4;
parameter STATE_TX_ACK_SCL_HIGH = 5;
parameter STATE_TX_STOP0 = 6;
parameter STATE_TX_STOP1 = 7;
parameter STATE_TX_STOP2 = 8;

reg [3:0] tx_state;
reg [3:0] next_tx_state;

always @* begin
	next_tx_state = tx_state;
	tx_req_clear = 1'b0;
	cur_bit_decr = 1'b0;
	cur_bit_reset = 1'b0;
	fifo_latch = 1'b0;

	sda_drive = 1'b0;
	scl_drive = 1'b0;
	sda_drive_val = 1'b1;
	scl_drive_val = 1'b1;
	
	case(tx_state)
		STATE_IDLE: begin
			if(tx_req_hist && !rx_busy) begin
				next_tx_state = STATE_TX_START;
			end
		end

		STATE_TX_START: begin
			tx_req_clear = 1'b1;
			sda_drive = 1'b1;
			scl_drive = 1'b1;
			sda_drive_val = 1'b0;
			cur_bit_reset = 1'b1;
			if(clock_counter == clock_div)
				next_tx_state = STATE_TX_SCL_LOW;
		end

		STATE_TX_SCL_LOW: begin
			sda_drive = 1'b1;
			scl_drive = 1'b1;
			sda_drive_val = fifo_char[cur_bit];
			scl_drive_val = 1'b0;
			if(clock_counter == clock_div)
				next_tx_state = STATE_TX_SCL_HIGH;
		end

		STATE_TX_SCL_HIGH: begin
			sda_drive = 1'b1;
			scl_drive = 1'b1;
			sda_drive_val = fifo_char[cur_bit];
			if(clock_counter == clock_div) begin
				cur_bit_decr = 1'b1;
				if(cur_bit > 0) begin
					next_tx_state = STATE_TX_SCL_LOW;
				end else begin
					next_tx_state = STATE_TX_ACK_SCL_LOW;
				end
			end
		end

		STATE_TX_ACK_SCL_LOW: begin
			scl_drive = 1'b1;
			scl_drive_val = 1'b0;
			if(clock_counter == clock_div) begin
				fifo_latch = 1'b1;
				next_tx_state = STATE_TX_ACK_SCL_HIGH;
			end
		end

		STATE_TX_ACK_SCL_HIGH: begin
			scl_drive = 1'b1;
			scl_drive_val = 1'b1;
			cur_bit_reset = 1'b1;
			if(clock_counter == clock_div) begin
				if(fifo_req == 1'b1)
					next_tx_state = STATE_TX_SCL_LOW;
				else
					next_tx_state = STATE_TX_STOP0;
			end
		end

		STATE_TX_STOP0: begin
			scl_drive = 1'b1;
			scl_drive_val = 1'b0;
			sda_drive = 1'b1;
			sda_drive_val = 1'b0;
			if(clock_counter == clock_div)
				next_tx_state = STATE_TX_STOP1;
		end

		STATE_TX_STOP1: begin
			scl_drive = 1'b1;
			scl_drive_val = 1'b1;
			sda_drive = 1'b1;
			sda_drive_val = 1'b0;
			if(clock_counter == clock_div)
				next_tx_state = STATE_TX_STOP2;
		end

		STATE_TX_STOP2: begin
			scl_drive = 1'b1;
			scl_drive_val = 1'b1;
			sda_drive = 1'b1;
			sda_drive_val = 1'b0;
			if(clock_counter == clock_div) begin
				fifo_latch = 1'b1;
				next_tx_state = STATE_IDLE;
			end
		end
	endcase
end

always @(posedge clk) begin
	if(reset) begin
		clock_counter <= 0;
		tx_req_hist <= 1'b0;
		tx_state <= STATE_IDLE;
	end else begin
		tx_state <= next_tx_state;

		tx_req_hist <= tx_req_hist | tx_req;
		if(tx_req_clear)
			tx_req_hist <= 1'b0;
	
		clock_counter <= clock_counter + 1;
		if(state != next_tx_state)
			clock_counter <= 0;

		if(cur_bit_reset)
			cur_bit <= 7;
		else if(cur_bit_decr)
			cur_bit <= cur_bit - 1;
	end
end

always @* begin
	next_rx_state = rx_state;
end

endmodule

