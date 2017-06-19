`include "include/ice_def.v"

module pwm_mod (clk, resetn, fifo_din, fifo_RE, fifo_empty, 
				start_tx, PWM_OUT, base_counter);

input			clk, resetn;

output			PWM_OUT;

input	[7:0]	fifo_din;
output			fifo_RE;
input			fifo_empty;

input			start_tx;

parameter BITS_PER_DC=22;	// 2^8 = 256 > PTS_T_PERIOD

input	[(BITS_PER_DC-1):0] base_counter;
wire	[BITS_PER_DC:0]		t_thres1_reg = (base_counter<<1); 
wire	[(BITS_PER_DC+2):0] t_thres0_reg = (base_counter<<3);
wire	[(BITS_PER_DC+3):0] t_period_reg = t_thres1_reg + t_thres0_reg;
reg		[(BITS_PER_DC+3):0]	counter, next_counter;

parameter BIT_POS_MAX=8;

reg				PWM_OUT_BUF, PWM_OUT;
reg		[2:0]	state, next_state;
reg				output_en, next_output_en;
reg				fifo_RE, next_fifo_RE;
reg		[2:0]	bit_position, next_bit_position;
wire			bit_extraction = (fifo_din & (8'b1<<bit_position)) ? 1 : 0;


always @ *
begin
	PWM_OUT_BUF = 0;
	if (output_en)
	begin
		if (bit_extraction)
		begin
			if (counter>t_thres1_reg)
				PWM_OUT_BUF = 1;
			else
				PWM_OUT_BUF = 0;
		end
		else
		begin
			if (counter>t_thres0_reg)
				PWM_OUT_BUF = 1;
			else
				PWM_OUT_BUF = 0;
		end
	end
	else
	begin
		PWM_OUT_BUF = 0;
	end
end

always @ (negedge resetn or posedge clk)
begin
	if (~resetn)
		PWM_OUT <= `SD 0;
	else
		PWM_OUT <= `SD PWM_OUT_BUF;
end

always @ (negedge resetn or posedge clk)
begin
	if (~resetn)
	begin
		state <= `SD 0;
		output_en <= `SD 0;
		fifo_RE <= `SD 0;
		bit_position <= `SD 0;
		counter <= `SD t_period_reg - 1;
	end
	else
	begin
		fifo_RE <= `SD next_fifo_RE;
		bit_position <= `SD next_bit_position;
		counter <= `SD next_counter;

		if(fifo_empty) begin
			state <= `SD 0;
			output_en <= `SD 1'b0;
		end
		else
		begin
			state <= `SD next_state;
			output_en <= `SD next_output_en;
		end
			
	end
end

always @ *
begin
	next_state = state;
	next_output_en = output_en;
	next_fifo_RE = 0;
	next_bit_position = bit_position;
	next_counter = counter;
	case (state)
		0:
		begin
			if (start_tx)
			begin
				next_state = 1;
			end
		end

		1:
		begin
			next_state = 2;
		end

		2:
		begin
			next_state = 3;
			next_output_en = 1;
			next_counter = t_period_reg -1;
			next_bit_position = 0;
		end

		3:
		begin
			if (counter>0)
				next_counter = counter - 1;
			else
			begin
				next_counter = t_period_reg -1;
				if (bit_position<(BIT_POS_MAX-1))
					next_bit_position = bit_position + 1;
				else
					next_bit_position = 0;
			end

			if ((counter==1)&&(bit_position==(BIT_POS_MAX-1)))
			begin
				next_fifo_RE = 1;
			end
		end

	endcase
end


endmodule

