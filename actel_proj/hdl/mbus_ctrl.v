/*
 * MBus Copyright 2015 Regents of the University of Michigan
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Last modified by: Ye-sheng Kuo <samkuo@umich.edu>
 * 05/25 '15: Add double latch for DIN
 *
 * 04/08 '13: Added glitch reset
 * */
`include "include/mbus_def.v"

module mbus_ctrl(
	input CLK_EXT,
	input RESETn,
	input CLKIN,
	output CLKOUT,
	input DIN,
	output reg DOUT,
	input [`WATCH_DOG_WIDTH-1:0] THRESHOLD
);

`include "include/mbus_func.v"

parameter BUS_IDLE = 0;
parameter BUS_WAIT_START = 3;
parameter BUS_START = 4;
parameter BUS_ARBITRATE = 1;
parameter BUS_PRIO = 2;
parameter BUS_ACTIVE = 5;
parameter BUS_INTERRUPT = 7;
parameter BUS_SWITCH_ROLE = 6;
parameter BUS_CONTROL0 = 8;
parameter BUS_CONTROL1 = 9;
parameter BUS_BACK_TO_IDLE = 10;

parameter NUM_OF_BUS_STATE = 11;
parameter START_CYCLES = 10;
parameter BUS_INTERRUPT_COUNTER = 6;

reg		[log2(START_CYCLES-1)-1:0] start_cycle_cnt, next_start_cycle_cnt;
reg		[log2(NUM_OF_BUS_STATE-1)-1:0] bus_state, next_bus_state, bus_state_neg;
reg		clk_en, next_clk_en;
reg		[log2(BUS_INTERRUPT_COUNTER-1)-1:0] bus_interrupt_cnt, next_bus_interrupt_cnt;

reg		clkin_sampled; 
reg		[2:0] din_sampled_neg, din_sampled_pos;

reg		[`WATCH_DOG_WIDTH-1:0] threshold_cnt, next_threshold_cnt;

reg din_dly_1, din_dly_2;

always @(posedge CLK_EXT or negedge RESETn) 
begin
	if (~RESETn) 
	begin
		din_dly_1 <= 1'b1;
		din_dly_2 <= 1'b1;
	end
	else begin
		din_dly_1 <= DIN;
		din_dly_2 <= din_dly_1;
	end
end


assign CLKOUT = (clk_en)? CLK_EXT : 1'b1;

wire [1:0] CONTROL_BITS = `CONTROL_SEQ;	// EOM?, ~ACK?

always @ (posedge CLK_EXT or negedge RESETn)
begin
	if (~RESETn)
	begin
		bus_state <= BUS_IDLE;
		start_cycle_cnt <= START_CYCLES - 1'b1;
		clk_en <= 0;
		bus_interrupt_cnt <= BUS_INTERRUPT_COUNTER - 1'b1;
		threshold_cnt <= 0;
	end
	else
	begin
		bus_state <= next_bus_state;
		start_cycle_cnt <= next_start_cycle_cnt;
		clk_en <= next_clk_en;
		bus_interrupt_cnt <= next_bus_interrupt_cnt;
		threshold_cnt <= next_threshold_cnt;
	end
end

always @ *
begin
	next_bus_state = bus_state;
	next_start_cycle_cnt = start_cycle_cnt;
	next_clk_en = clk_en;
	next_bus_interrupt_cnt = bus_interrupt_cnt;
	next_threshold_cnt = threshold_cnt;

	case (bus_state)
		BUS_IDLE:
		begin
			if (~din_dly_2)
				next_bus_state = BUS_WAIT_START;	
			next_start_cycle_cnt = START_CYCLES - 1'b1;
		end

		BUS_WAIT_START:
		begin
			next_threshold_cnt = 0;
			if (start_cycle_cnt)
				next_start_cycle_cnt = start_cycle_cnt - 1'b1;
			else
			begin
				if (~din_dly_2)
				begin
					next_clk_en = 1;
					next_bus_state = BUS_START;
				end
				else
					next_bus_state = BUS_IDLE;
			end
		end

		BUS_START:
		begin
			next_bus_state = BUS_ARBITRATE;
		end

		BUS_ARBITRATE:
		begin
			next_bus_state = BUS_PRIO;
			// Glitch, reset bus immediately
			if (DIN)
				next_threshold_cnt = THRESHOLD;
		end

		BUS_PRIO:
		begin
			next_bus_state = BUS_ACTIVE;
		end

		BUS_ACTIVE:
		begin
			if ((threshold_cnt<THRESHOLD)&&(~clkin_sampled))
				next_threshold_cnt = threshold_cnt + 1'b1;
			else
			begin
				next_clk_en = 0;
				next_bus_state = BUS_INTERRUPT;
			end

			next_bus_interrupt_cnt = BUS_INTERRUPT_COUNTER - 1'b1;
		end

		BUS_INTERRUPT:
		begin
			if (bus_interrupt_cnt)
				next_bus_interrupt_cnt = bus_interrupt_cnt - 1'b1;
			else
			begin
				if ({din_sampled_neg, din_sampled_pos}==6'b111_000)
				begin
					next_bus_state = BUS_SWITCH_ROLE;
					next_clk_en = 1;
				end
			end
		end

		BUS_SWITCH_ROLE:
		begin
			next_bus_state = BUS_CONTROL0;
		end

		BUS_CONTROL0:
		begin
			next_bus_state = BUS_CONTROL1;
		end

		BUS_CONTROL1:
		begin
			next_bus_state = BUS_BACK_TO_IDLE;
		end

		BUS_BACK_TO_IDLE:
		begin
			if (~DIN)
			begin
				next_bus_state = BUS_WAIT_START;
				next_start_cycle_cnt = 1;
			end
			else
			begin
				next_bus_state = BUS_IDLE;
			end
			next_clk_en = 0;
		end
	endcase
end

always @ (negedge CLK_EXT or negedge RESETn)
begin
	if (~RESETn)
	begin
		din_sampled_neg <= 0;
		bus_state_neg <= BUS_IDLE;
	end
	else
	begin
		if (bus_state==BUS_INTERRUPT)
			din_sampled_neg <= {din_sampled_neg[1:0], DIN};
		bus_state_neg <= bus_state;
	end
end

always @ (posedge CLK_EXT or negedge RESETn)
begin
	if (~RESETn)
	begin
		din_sampled_pos <= 0;
		clkin_sampled <= 0;
	end
	else
	begin
		if (bus_state==BUS_INTERRUPT)
			din_sampled_pos <= {din_sampled_pos[1:0], DIN};
		clkin_sampled <= CLKIN;
	end
end

always @ *
begin
	DOUT = DIN;
	case (bus_state_neg)
		BUS_IDLE: begin DOUT = 1; end
		BUS_WAIT_START: begin DOUT = 1; end
		BUS_START: begin DOUT = 1; end
		BUS_INTERRUPT: begin DOUT = CLK_EXT; end
		BUS_CONTROL0: begin if (threshold_cnt==THRESHOLD) DOUT = (~CONTROL_BITS[1]); end
		BUS_BACK_TO_IDLE: begin DOUT = 1; end
	endcase

end
endmodule

