`include "include/ice_def.v"

module ice_bus_controller(clk, rst, rx_char, rx_char_valid, tx_char, tx_char_valid, tx_char_ready, generate_nak, evt_id, ma_data, ma_addr, ma_data_valid, ma_frame_valid, sl_overflow, sl_addr, sl_tail, sl_latch_tail, sl_data, sl_arb_request, sl_arb_grant);
parameter NUM_DEV=2;

input clk;
input rst;

//Interface to UART (or other character device)
input [7:0] rx_char;
input rx_char_valid;
output [7:0] tx_char;
output reg tx_char_valid;
input tx_char_ready;

//Immediate NAKs have their own controller =)
output reg generate_nak;
output reg [7:0] evt_id;

//Master-driven bus (data & control)
output [7:0] ma_data;
output reg [7:0] ma_addr;
output reg ma_data_valid;
output reg ma_frame_valid;
input sl_overflow;

//Bus controller outputs (data & control)
output [8:0] sl_addr;
input [8:0] sl_tail;
output reg sl_latch_tail;
input [8:0] sl_data;
input [NUM_DEV-1:0] sl_arb_request;
output [NUM_DEV-1:0] sl_arb_grant;

//For now the master bus is just a direct connection to the UART rx character bus.  May always be this way??
assign ma_data = rx_char;

wire pri_en, pri_granted;
wire pri_latch;
priority_select #(NUM_DEV) pri1(
	.clk(clk),
	.rst(rst),
	.enable(pri_en),
	.latch(pri_latch),
	
	.requests(sl_arb_request),
	.grants(sl_arb_grant),
	.granted(pri_granted)
);

reg record_addr, record_evt_id;
reg byte_counter_incr, byte_counter_decr, byte_counter_reset, set_byte_counter;
reg shift_in_pyld_len;
reg [7:0] byte_counter;
reg [7:0] payload_len;

//Bus controller RX state machine
parameter STATE_RX_IDLE = 0;
parameter STATE_RX_ID = 1;
parameter STATE_RX_LEN = 2;
parameter STATE_RX_PYLD = 3;
parameter STATE_RX_OVERFLOW = 4;
reg [3:0] state, next_state;

always @* begin
	next_state = state;
	record_addr = 1'b0;
	record_evt_id = 1'b0;
	byte_counter_incr = 1'b0;
	byte_counter_decr = 1'b0;
	byte_counter_reset = 1'b0;
	shift_in_pyld_len = 1'b0;
	ma_data_valid = 1'b0;
	ma_frame_valid = 1'b0;
	set_byte_counter = 1'b0;
	generate_nak = 1'b0;
	
	case(state)
		STATE_RX_IDLE: begin
			record_addr = 1'b1;
			ma_frame_valid = rx_char_valid;
			byte_counter_reset = 1'b1;
			if(rx_char_valid)
				next_state = STATE_RX_ID;
		end
		
		STATE_RX_ID: begin
			ma_frame_valid = 1'b1;
			ma_data_valid = rx_char_valid;
			record_evt_id = 1'b1;
			if(rx_char_valid)
				next_state = STATE_RX_LEN;
		end
		
		STATE_RX_LEN: begin
			ma_frame_valid = 1'b1;
			ma_data_valid = rx_char_valid;
			shift_in_pyld_len = rx_char_valid;
			if(rx_char_valid) begin
				byte_counter_reset = 1'b1;
				next_state = STATE_RX_PYLD;
			end
		end
		
		STATE_RX_PYLD: begin
			ma_frame_valid = 1'b1;
			ma_data_valid = rx_char_valid;
			byte_counter_incr = rx_char_valid;
			if(byte_counter == payload_len)
				next_state = STATE_RX_IDLE;
			else if(sl_overflow)
				next_state = STATE_RX_OVERFLOW;
		end
		
		STATE_RX_OVERFLOW: begin
			generate_nak = 1'b1;
			next_state = STATE_RX_IDLE;
		end
	endcase
end

always @(posedge clk) begin
	
	if(rst) begin
		state <= `SD STATE_RX_IDLE;
		byte_counter <= `SD 16'd0;
        payload_len <= `SD 8'h0;
        evt_id <= `SD 8'h0;

	end else begin
		state <= `SD next_state;
			
		if(shift_in_pyld_len) begin
			payload_len <= `SD rx_char;
		end
		if(record_addr)
			ma_addr <= `SD rx_char;
		if(record_evt_id)
			evt_id <= `SD rx_char;

		//Byte counter keeps track of packets up to 65535 bytes in size
		if(byte_counter_reset)
			byte_counter <= `SD 16'd0;
		else if(byte_counter_incr)
			byte_counter <= `SD byte_counter + 16'd1;
	end
end

//TX state machine...
//assign tx_char_valid = tx_char_ready & pri_granted;
assign pri_latch = ~pri_granted;
assign pri_en = 1'b1;

reg [8:0] sl_addr_offset;
reg [7:0] sl_addr_offset_save;
assign sl_addr = sl_tail + sl_addr_offset;

parameter STATE_TX_IDLE = 0;
parameter STATE_TX_GETLEN = 1;
parameter STATE_TX_HEADER_PRE = 2;
parameter STATE_TX_HEADER = 3;
parameter STATE_TX_LEN = 4;
parameter STATE_TX_PAYLOAD = 5;
parameter STATE_TX_LATCH_TAIL = 6;

reg [3:0] tx_state, next_tx_state;
reg save_offset;
reg tx_len;
reg addr_offset_clear, addr_offset_incr;

assign tx_char = (tx_len) ? sl_addr_offset_save[7:0] : sl_data[7:0];

always @(posedge clk) begin
	if(rst) begin
		tx_state <= `SD STATE_TX_IDLE;
		sl_addr_offset <= `SD 0;
        sl_addr_offset_save <= `SD 8'h0;

	end else begin
		tx_state <= `SD next_tx_state;
		if(addr_offset_clear)
			sl_addr_offset <= `SD 0;
		else if(addr_offset_incr)
			sl_addr_offset <= `SD sl_addr_offset + 1;
		if(save_offset)
			sl_addr_offset_save <= `SD sl_addr_offset - 4;
	end
end

always @* begin
	next_tx_state = tx_state;
	addr_offset_clear = 1'b0;
	addr_offset_incr = 1'b0;
	save_offset = 1'b0;
	tx_char_valid = 1'b0;
	tx_len = 1'b0;
	sl_latch_tail = 1'b0;
	case(tx_state)
		STATE_TX_IDLE: begin
			addr_offset_clear = 1'b1;
			if(pri_granted) begin
				next_tx_state = STATE_TX_GETLEN;
			end
		end

		STATE_TX_GETLEN: begin
			addr_offset_incr = 1'b1;
			if(sl_data[8]) begin
				save_offset = 1'b1;
				addr_offset_clear = 1'b1;
				next_tx_state = STATE_TX_HEADER_PRE;
			end
		end

		STATE_TX_HEADER_PRE: begin
			//Have to wait one cycle before txing anything to
			//allow RAM to sync
			next_tx_state = STATE_TX_HEADER;
		end

		STATE_TX_HEADER: begin
			addr_offset_incr = tx_char_ready;
			tx_char_valid = tx_char_ready;
			if(sl_addr_offset == 2)
				next_tx_state = STATE_TX_LEN;
		end

		STATE_TX_LEN: begin
			addr_offset_incr = tx_char_ready;
			tx_char_valid = tx_char_ready;
			tx_len = 1'b1;
			if(tx_char_ready)
				next_tx_state = STATE_TX_PAYLOAD;
		end

		STATE_TX_PAYLOAD: begin
			addr_offset_incr = tx_char_ready;
			tx_char_valid = tx_char_ready;
			if(sl_data[8]) begin
				addr_offset_incr = 1'b1;
				next_tx_state = STATE_TX_LATCH_TAIL;
			end
		end

		STATE_TX_LATCH_TAIL: begin
			sl_latch_tail = 1'b1;
			next_tx_state = STATE_TX_IDLE;
		end
	endcase
end

endmodule
