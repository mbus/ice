module discrete_int(
	input clk,
	input reset,
	
	input SCL_DISCRETE_BUF,
	output SCL_PD,
	output SCL_PU,
	output SCL_TRI,
	
	input SDA_DISCRETE_BUF,
	output SDA_PD,
	output SDA_PU,
	output SDA_TRI,

	input [7:0] tx_char,
	input tx_char_latch,
	input tx_req,

	output reg [7:0] rx_char,
	output reg rx_char_latch,
	output reg rx_req
);

reg SDA_mpu;
reg SDA_mpd;
assign SDA_PD = SDA_mpd;
assign SDA_PU = ~SDA_mpu;
assign SDA_TRI = SDA_mpd | SDA_mpu;

reg SCL_mpu;
reg SCL_mpd;
assign SCL_PD = SCL_mpd;
assign SCL_PU = ~SCL_mpu;
assign SCL_TRI = SCL_mpd | SCL_mpu;

parameter clock_div = 25;

//FIFO to queue up outgoing transmissions.  An extra bit to denote frame boundaries...
//NOTE: Make sure this doesn't overfill
wire [7:0] fifo_char;
wire fifo_valid;
wire fifo_req;
reg fifo_latch;
fifo #(9,16) f1(
	.clk(clk),
	.reset(reset),
	.in({tx_req, tx_char}),
	.in_latch(tx_char_latch | tx_req),
	.out({fifo_req, fifo_char}),
	.out_latch(fifo_latch),
	.out_valid(fifo_valid)
);

reg rx_busy;
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
	SCL_mpu <= (scl_drive) ? ((scl_drive_val) ? 1'b1 : 1'b0) : 1'b0;
	SCL_mpd <= (scl_drive) ? ((scl_drive_val) ? 1'b0 : 1'b1) : 1'b0;
	
	SDA_mpu <= (sda_drive) ? ((sda_drive_val) ? 1'b1 : 1'b0) : 1'b0;
	SDA_mpd <= (sda_drive) ? ((sda_drive_val) ? 1'b0 : 1'b1) : 1'b0;

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

reg [3:0] rx_state;
reg [3:0] next_rx_state;
reg rx_counter_incr;
reg rx_counter_reset;
reg rx_shift_out;

always @* begin
	next_rx_state = rx_state;
	next_rx_busy = 1'b1;
	rx_counter_incr = 1'b0;
	rx_counter_reset = 1'b0;
	rx_char_latch = 1'b0;
	rx_req = 1'b0;
	rx_shift_out = 1'b0;
	
	case(rx_state)
		STATE_RX_IDLE: begin
			next_rx_busy = 1'b0;
			rx_counter_reset = 1'b1;
			if(sda_db == 1'b0)
				next_rx_state = STATE_RX_DATA;
		end
		
		STATE_RX_DATA: begin
			if(scl_db_last == 1'b0 && scl_db == 1'b1) begin
				rx_counter_incr = 1'b1;
				rx_shift_out = 1'b1;
				if(rx_counter == 4'd7) begin
					rx_counter_reset = 1'b1;
					rx_char_latch = 1'b1;
					next_rx_state = STATE_RX_ACK;
				end
			end
		end
		
		STATE_RX_ACK: begin
			if(sda_db_last == 1'b0 && sda_db == 1'b1 && scl_db == 1'b1) begin
				next_rx_state = STATE_RX_IDLE;
			end else if(scl_db_last == 1'b1 && scl_db == 1'b0) begin
				rx_counter_incr = 1'b1;
				if(rx_counter == 4'd1) begin
					rx_counter_reset = 1'b1;
					next_rx_state = STATE_RX_DATA;
				end
			end
		end
	endcase
end

always @(posedge clk) begin
	rx_busy <= next_rx_busy;
	
	//Debouncing for SDA & SCL
	sda_db_0 <= SDA_DISCRETE_BUF;
	sda_db <= sda_db_0;
	scl_db_0 <= SCL_DISCRETE_BUF;
	scl_db <= scl_db_0;
	
	sda_db_last <= sda_db;
	scl_db_last <= scl_db;
	
	if(rx_counter_incr)
		rx_counter <= rx_counter + 1;
	else if(rx_counter_reset)
		rx_counter <= 0;
		
	if(rx_shift_out)
		rx_char <= {rx_char[6:0], sda_db};
	
	if(reset) begin
		rx_state <= STATE_RX_IDLE;
	end else begin
		rx_state <= next_rx_state;
	end
end

endmodule

