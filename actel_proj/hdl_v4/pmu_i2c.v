`include "include/ice_def.v"

module pmu_i2c(
	input clk,
	input reset,
	
	inout scl,
	inout sda,
	
	input [7:0] data,
	input start,
	input done,
	input rw,
	output reg data_latch,
	
	output reg ready,
	output reg failed,
	output reg [7:0] in_data,
	output reg in_data_valid,
	input clear_failed
);
parameter CLK_DIV = 50;

reg [7:0] state_counter;
reg [7:0] latched_data;
reg [2:0] shift_counter;
reg sda_pd, sda_pd_latched;
reg scl_pd, scl_pd_latched;
reg latch_ack;
reg shift_latched_data;
reg rw_latched;
reg in_data_latch;

assign scl = (scl_pd_latched) ? 1'b0 : 1'bz;
assign sda = (sda_pd_latched & rw_latched) ? 1'b0 : 1'bz;

reg [3:0] state, next_state;
parameter STATE_IDLE = 0;
parameter STATE_START = 1;
parameter STATE_SCL_START = 2;
parameter STATE_LATCH_DATA = 3;
parameter STATE_DATA = 4;
parameter STATE_SHIFT_DATA = 5;
parameter STATE_ACK = 6;
parameter STATE_STOP = 7;

always @(posedge clk) begin
	if(reset) begin
		state <= `SD STATE_IDLE;
		state_counter <= `SD 0;
		shift_counter <= `SD 0;
		failed <= `SD 0;
		rw_latched <= `SD 0;

        in_data <= `SD 8'h0;

	end else begin
		state <= `SD next_state;
		
		scl_pd_latched <= `SD scl_pd;
		sda_pd_latched <= `SD sda_pd;
		
		//Counter for keeping track of slow I2C clock
		if(next_state != state)
			state_counter <= `SD 0;
		else
			state_counter <= `SD state_counter + 1;
			
		//Latch data locally every time we're ready for it
		if(data_latch)
			latched_data <= `SD data;
		if(ready)
			rw_latched <= `SD rw;
		if(shift_latched_data) begin
			shift_counter <= `SD shift_counter + 1'b1;
			latched_data <= `SD {latched_data[6:0], 1'b0};
		end
		
		//Latch the ack to see if the chip acked or not
		if(latch_ack)
			failed <= `SD sda;
		if(clear_failed)
			failed <= `SD 1'b0;
			
		//Shift in data if we're actually reading data back over I2C
		if(in_data_latch)
			in_data <= `SD {in_data[6:0], sda};
	end
end

always @* begin
	next_state = state;
	sda_pd = 1'b0;
	scl_pd = 1'b0;
	data_latch = 1'b0;
	shift_latched_data = 1'b0;
	ready = 1'b0;
	latch_ack = 1'b0;
	in_data_valid = 1'b0;
	in_data_latch = 1'b0;
	
	case(state)
		STATE_IDLE: begin
			ready = 1'b1;
			if(start)
				next_state = STATE_START;
		end
		
		STATE_START: begin
			sda_pd = 1'b1;
			if(state_counter == CLK_DIV-1)
				next_state = STATE_SCL_START;
		end
		
		STATE_SCL_START: begin
			sda_pd = 1'b1;
			scl_pd = 1'b1;
			if(state_counter == CLK_DIV/4)
				next_state = STATE_LATCH_DATA;
		end
		
		STATE_LATCH_DATA: begin
			sda_pd = 1'b1;
			scl_pd = 1'b1;
			data_latch = 1'b1;
			next_state = STATE_DATA;
		end
		
		STATE_DATA: begin
			if(rw_latched)
				sda_pd = ~latched_data[7];
			if(state_counter < CLK_DIV/4)
				scl_pd = 1'b1;
			else if(state_counter > CLK_DIV*3/4)
				scl_pd = 1'b1;
			if(state_counter == CLK_DIV/2)
				in_data_latch = 1'b1;
			if(state_counter == CLK_DIV-1)
				next_state = STATE_SHIFT_DATA;
		end
		
		STATE_SHIFT_DATA: begin
			shift_latched_data = 1'b1;
			if(shift_counter == 7)
				next_state = STATE_ACK;
			else
				next_state = STATE_DATA;
		end
		
		STATE_ACK: begin
			if(state_counter < CLK_DIV/4)
				scl_pd = 1'b1;
			else if(state_counter > CLK_DIV*3/4)
				scl_pd = 1'b1;
			if(state_counter == CLK_DIV/2)
				latch_ack = 1'b1;
			if(state_counter == CLK_DIV-1) begin
				in_data_valid = 1'b1;
				if(failed || done)
					next_state = STATE_STOP;
				else
					next_state = STATE_LATCH_DATA;
			end
		end
		
		STATE_STOP: begin
			if(state_counter < CLK_DIV-1)
				sda_pd = 1'b1;
			if(state_counter < CLK_DIV/4)
				scl_pd = 1'b1;
			if(state_counter == CLK_DIV*2-1)
				next_state = STATE_IDLE;
		end
	endcase
end

endmodule
