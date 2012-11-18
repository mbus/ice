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

	//I2C address match interface
	input [7:0] addr_match_char,
	input addr_match_latch,
	input addr_match_reset,

	input [7:0] tx_char,
	input tx_char_latch,
	input tx_req,

	output reg [7:0] rx_char,
	output reg rx_char_latch,
	output reg rx_req
);

reg sda_drive_real;
reg ack;

reg SDA_mpu;
reg SDA_mpd;
assign SDA_PD = (ack) ? 1'b0 : SDA_mpd;
assign SDA_PU = (ack) ? 1'b0 : ~SDA_mpu;
assign SDA_TRI = (ack) ? sda_drive_real : 1'b1;

reg SCL_mpu;
reg SCL_mpd;
assign SCL_PD = SCL_mpd;
assign SCL_PU = ~SCL_mpu;
assign SCL_TRI = SCL_mpd | SCL_mpu;

parameter clock_div = 99;

//FIFO to queue up outgoing transmissions.  An extra bit to denote frame boundaries...
//NOTE: Make sure this doesn't overfill
wire [7:0] fifo_char;
wire fifo_valid;
wire fifo_req;
reg fifo_latch;
fifo #(9,4) f1(
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
reg sda_drive, scl_drive;
reg sda_drive_val, scl_drive_val;
reg tx_req_hist;

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
			if(tx_req_hist && !rx_busy)
				next_tx_state = STATE_TX_START;
		end

		STATE_TX_START: begin
			tx_req_clear = 1'b1;
			sda_drive = 1'b1;
			scl_drive = 1'b1;
			if(clock_counter <= clock_div)
				sda_drive_val = 1'b1;
			else begin
				if(fifo_req == 1'b1) //Jump to the stop bit in case this is a blank I2C transaction (special for M3)
					next_tx_state = STATE_TX_STOP1;
				else
					sda_drive_val = 1'b0;
			end
			cur_bit_reset = 1'b1;
			if(clock_counter == clock_div*2) begin
				next_tx_state = STATE_TX_SCL_LOW;
			end
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
				if(fifo_req == 1'b0 && fifo_valid)
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
			sda_drive_val = 1'b1;
			if(clock_counter == clock_div) begin
				fifo_latch = 1'b1;
				next_tx_state = STATE_IDLE;
			end
		end
	endcase
end

reg [7:0] sda_drive_counter;
always @(posedge clk) begin
	
	SCL_mpu <= (scl_drive) ? ((scl_drive_val) ? 1'b1 : 1'b0) : 1'b0;
	SCL_mpd <= (scl_drive) ? ((scl_drive_val) ? 1'b0 : 1'b1) : 1'b0;
	
	//Every time we stop driving SDA, we should pull it high first
	if(!sda_drive) begin
		if(sda_drive_counter <= 11) begin
			sda_drive_counter <= sda_drive_counter + 1;
			sda_drive_real <= 1'b1;
		end else if(sda_drive_counter <= 23) begin
			sda_drive_counter <= sda_drive_counter + 1;
			sda_drive_real <= 1'b1;
			SDA_mpu <= 1'b1;
			SDA_mpd <= 1'b0;
		end else if(sda_drive_counter <= 24) begin
			sda_drive_counter <= sda_drive_counter + 1;
			sda_drive_real <= 1'b0;
			SDA_mpu <= 1'b1;
			SDA_mpd <= 1'b0;
		end else begin
			SDA_mpu <= 1'b0;
			SDA_mpd <= 1'b0;
		end
	end else if(sda_drive) begin
		//Everything SDA is delayed by 1/4 cycle
		if(clock_counter >= (clock_div >> 2)) begin
			SDA_mpu <= (sda_drive) ? ((sda_drive_val) ? 1'b1 : 1'b0) : 1'b0;
			SDA_mpd <= (sda_drive) ? ((sda_drive_val) ? 1'b0 : 1'b1) : 1'b0;
			sda_drive_counter <= 0;
			sda_drive_real <= 1'b1;
		end
	end

	if(reset) begin
		clock_counter <= 0;
		tx_req_hist <= 1'b0;
		tx_state <= STATE_IDLE;
		sda_drive_real <= 1'b0;
		sda_drive_counter <= 0;
	end else begin
		tx_state <= next_tx_state;

		tx_req_hist <= tx_req_hist | tx_req;
		if(tx_req_clear)
			tx_req_hist <= 1'b0;
	
		clock_counter <= clock_counter + 1;
		if(tx_state != next_tx_state)
			clock_counter <= 0;

		if(cur_bit_reset)
			cur_bit <= 7;
		else if(cur_bit_decr)
			cur_bit <= cur_bit - 1;
	end
end

parameter STATE_RX_IDLE=0;
parameter STATE_RX_DATA=1;
parameter STATE_RX_ACK=2;

reg [3:0] rx_state, next_rx_state;
reg [3:0] rx_counter;
reg rx_counter_incr;
reg rx_counter_reset;
reg rx_shift_out;
reg next_rx_busy, next_rx_char_latch;
reg sda_db, sda_db_last, sda_db_0;
reg scl_db, scl_db_last, scl_db_0;
reg addr_enable, addr_disable, cur_addr_flag;
reg [7:0] cur_addr;
reg ack_set, ack_reset;

//Address matching RAM (can accept any I2C address)
wire [7:0] cur_addr_word;
reg [3:0] addr_match_addr;
ram #(8,4) addrMatchRam(
	.clk(clk),
	.reset(reset),
	.in_data(addr_match_char),
	.in_addr(addr_match_addr),
	.in_latch(addr_match_latch),
	.out_addr(cur_addr[7:4]),
	.out_data(cur_addr_word)
);
wire addr_match = cur_addr_word[cur_addr[3:1]];

always @* begin
	next_rx_state = rx_state;
	next_rx_busy = 1'b1;
	rx_counter_incr = 1'b0;
	rx_counter_reset = 1'b0;
	next_rx_char_latch = 1'b0;
	rx_req = 1'b0;
	rx_shift_out = 1'b0;
	addr_enable = 1'b0;
	addr_disable = 1'b0;
	ack_set = 1'b0;
	ack_reset = 1'b0;
	
	case(rx_state)
		STATE_RX_IDLE: begin
			next_rx_busy = 1'b0;
			rx_counter_reset = 1'b1;
			addr_enable = 1'b1;
			if(sda_db == 1'b0 && scl_db == 1'b1)
				next_rx_state = STATE_RX_DATA;
		end
		
		STATE_RX_DATA: begin
			if(scl_db_last == 1'b0 && scl_db == 1'b1) begin
				rx_counter_incr = 1'b1;
				rx_shift_out = 1'b1;
				if(rx_counter == 4'd7) begin
					rx_counter_reset = 1'b1;
					next_rx_char_latch = 1'b1;
					next_rx_state = STATE_RX_ACK;
				end
			end
			//If we've seen a stop bit, proceed to go, collect $200
			if(sda_db_last == 1'b0 && sda_db == 1'b1 && scl_db == 1'b1) begin
				rx_req = 1'b1;
				next_rx_state = STATE_RX_IDLE;
			end
		end
		
		STATE_RX_ACK: begin
			//According to the 'mm3 sensor node - I2C.pptx' documentation, I can just pull down for ACK during the whole cycle without any repercussions
			addr_disable = 1'b1;
			if(sda_db_last == 1'b0 && sda_db == 1'b1 && scl_db == 1'b1) begin
				rx_req = 1'b1;
				next_rx_state = STATE_RX_IDLE;
			end else if(scl_db_last == 1'b1 && scl_db == 1'b0) begin
				if(addr_match)
					ack_set = 1'b1;
				//TODO: Need some sort of address matching in here!!!
				rx_counter_incr = 1'b1;
				if(rx_counter == 4'd1) begin
					ack_reset = 1'b1;
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
	
	rx_char_latch <= next_rx_char_latch;
	
	if(rx_counter_reset)
		rx_counter <= 0;
	else if(rx_counter_incr)
		rx_counter <= rx_counter + 1;
		
	if(rx_shift_out)
		rx_char <= {rx_char[6:0], sda_db};

	//First byte of the I2C transaction is the I2C address
	if(addr_enable)
		cur_addr_flag <= 1'b1;
	else if(addr_disable)
		cur_addr_flag <= 1'b0;
	if(rx_shift_out && cur_addr_flag)
		cur_addr <= {cur_addr[6:0], sda_db};

	//Ack overrides the tx state machine logic to pull SDA down
	if(ack_reset)
		ack <= 1'b0;
	else if(ack_set)
		ack <= 1'b1;

	//Increment through the address match RAM when loading stuff in
	if(addr_match_reset)
		addr_match_addr <= 0;
	else if(addr_match_latch)
		addr_match_addr <= addr_match_addr + 1;

	if(reset) begin
		rx_state <= STATE_RX_IDLE;
		addr_match_addr <= 4'd0;
	end else begin
		rx_state <= next_rx_state;
	end
end

endmodule

