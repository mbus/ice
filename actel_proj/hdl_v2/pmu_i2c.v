module pmu_i2c(
	input clk,
	input reset,
	
	inout scl,
	inout sda,
	
	input [7:0] data,
	input start,
	input done,
	output reg data_latch,
	
	output reg ready,
	output reg failed,
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

assign scl = (scl_pd_latched) ? 1'b0 : 1'bz;
assign sda = (sda_pd_latched) ? 1'b0 : 1'bz;

reg [3:0] state, next_state;
parameter STATE_IDLE = 0;
parameter STATE_START = 1;
parameter STATE_LATCH_DATA = 2;
parameter STATE_DATA = 3;
parameter STATE_SHIFT_DATA = 4;
parameter STATE_ACK = 5;

always @(posedge clk) begin
	scl_pd_latched <= scl_pd;
	sda_pd_latched <= sda_pd;

	if(reset) begin
		state <= STATE_IDLE;
		state_counter <= 0;
		shift_counter <= 0;
		failed <= 0;
	end else begin
		state <= next_state;
		
		//Counter for keeping track of slow I2C clock
		if(next_state != state)
			state_counter <= 0;
		else
			state_counter <= state_counter + 1;
			
		//Latch data locally every time we're ready for it
		if(data_latch)
			latched_data <= data;
		if(shift_latched_data) begin
			shift_counter <= shift_counter + 1'b1;
			latched_data <= {latched_data[6:0], 1'b0};
		end
		
		//Latch the ack to see if the chip acked or not
		if(latch_ack)
			failed <= sda;
		if(clear_failed)
			failed <= 1'b0;
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
	
	case(state)
		STATE_IDLE: begin
			ready = 1'b1;
			if(start)
				next_state = STATE_START;
		end
		
		STATE_START: begin
			sda_pd = 1'b1;
			if(state_counter == CLK_DIV-1)
				next_state = STATE_DATA;
		end
		
		STATE_LATCH_DATA: begin
			sda_pd = 1'b1;
			data_latch = 1'b1;
			next_state = STATE_DATA;
		end
		
		STATE_DATA: begin
			sda_pd = ~latched_data[7];
			if(state_counter < CLK_DIV/2)
				scl_pd = 1'b1;
			if(state_counter == CLK_DIV-1)
				next_state = STATE_SHIFT_DATA;
		end
		
		STATE_SHIFT_DATA: begin
			shift_latched_data = 1'b1;
			if(shift_counter == 7)
				next_state = STATE_ACK;
		end
		
		STATE_ACK: begin
			if(state_counter < CLK_DIV/2)
				scl_pd = 1'b1;
			if(state_counter == CLK_DIV/2)
				latch_ack = 1'b1;
			if(state_counter == CLK_DIV-1) begin
				if(failed || done)
					next_state = STATE_IDLE;
				else
					next_state = STATE_LATCH_DATA;
			end
		end
	endcase
end

endmodule
