module ice_bus_controller(
	input clk,
	input rst,
	
	//Interface to UART (or other character device)
	input [7:0] rx_char,
	input rx_char_valid,
	output [7:0] tx_char,
	output tx_char_valid,
	input tx_char_ready,
	
	//Master-driven bus (data & control)
	output [7:0] ma_data,
	output [7:0] ma_addr,
	output ma_data_valid,
	output ma_frame_valid,
	output ma_arb_grant,
	input sl_overflow,
	
	//Bus controller outputs (data & control)
	input [7:0] sl_data,
	input sl_arb_request,
	input sl_data_valid,
	input sl_frame_valid
);
parameter NUM_DEV=2;

wire [NUM_DEV-1:0] ma_arb_grant, sl_arb_request;

wire pri_en;
priority_select pri1(
	.enable(pri_en),
	
	.requests(sl_arb_request),
	.grants(ma_arb_grant)
);

reg record_addr, record_evt_id;
reg next_frame_valid;
reg [15:0] byte_counter;
reg [15:0] payload_len;
reg [7:0] evt_id;

//Bus controller RX state machine
parameter STATE_RX_IDLE = 0;

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
	
	case(rx_state)
		STATE_RX_IDLE: begin
			record_addr = 1'b1;
			byte_counter_reset = 1'b1;
			if(rx_char_vaild)
				next_state = STATE_RX_ID;
		end
		
		STATE_RX_ID: begin
			ma_data_valid = rx_char_valid;
			record_evt_id = 1'b1;
			if(rx_char_valid)
				next_state = STATE_RX_LEN;
		end
		
		STATE_RX_LEN: begin
			byte_counter_incr = rx_char_valid;
			shift_in_pyld_len = rx_char_valid;
			if(byte_counter[1:0] == 2'd2) begin
				byte_counter_reset = 1'b1;
				next_state = STATE_RX_PYLD;
			end
		end
		
		STATE_RX_PYLD: begin
			ma_frame_valid = 1'b1;
			byte_counter_incr = rx_char_valid;
			if(byte_counter == payload_len)
				next_state = STATE_RX_IDLE;
			else if(sl_overflow)
				next_state = STATE_RX_OVERFLOW
		end
		
		STATE_RX_OVERFLOW: begin
			//TODO: FIgure out how to resolve contention between this state machine and the TX state machine which could be doing something else
		end
	endcase
end

always @(posedge clk) begin
	if(shift_in_pyld_len)
		payload_len <= {payload_len[7:0], rx_char};
	if(record_addr)
		ma_addr <= rx_char;
	if(record_evt_id)
		evt_id <= rx_char;

	if(rst) begin
		state <= STATE_IDLE;
		byte_counter <= 16'd0;
	end else begin
			
		//Byte counter keeps track of packets up to 65535 bytes in size
		if(byte_counter_reset)
			byte_counter <= 16'd0;
		else if(byte_counter_incr)
			byte_counter <= byte_counter + 16'd1;
	end
end

endmodule
