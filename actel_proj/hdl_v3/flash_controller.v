`include "include/ice_def.v"

//This module stores and replays command sequences through Micron series NOR flash chips (M25PXX)
module flash_controller(
	input clk,
	input rst,

	//Interface to flash chip
	output FLASH_D,
	output FLASH_C,
	output FLASH_CSn,
	output FLASH_WPn,
	output FLASH_HOLDn,
	input FLASH_Q,
	
	//Interject signals to/from UART controller
	input [7:0] uart_data,
	input uart_data_strobe,
	output [7:0] out_data,
	output reg out_data_strobe,

	//Also listen to state of ICE bus controller
	input ice_bus_idle,

	//Last inputs select the desired functionality of this block
	input record_enable,
	input playback_enable
);


reg [7:0] flash_data;
wire [7:0] flash_out_data;
reg flash_latch;
reg flash_continue;
wire flash_ready;

assign out_data = flash_out_data;

//FIFO used to buffer incoming data from 
wire fifo_out_bus_idle, fifo_out_valid;
reg fifo_out_latch;
wire [7:0] fifo_out_uart_data;
fifo #(9,9) ff(
	.clk(clk),
	.rst(rst),
	.in_data({ice_bus_idle,uart_data}),
	.in_data_latch(uart_data_strobe),
	.out_data({fifo_out_bus_idle,fifo_out_uart_data}),
	.out_data_latch(fifo_out_latch),
	.out_data_valid(fifo_out_valid)
);

micron_flash_impl mfi(
	.clk(clk),
	.rst(rst),
	.FLASH_D(FLASH_D),
	.FLASH_C(FLASH_C),
	.FLASH_CSn(FLASH_CSn),
	.FLASH_WPn(FLASH_WPn),
	.FLASH_HOLDn(FLASH_HOLDn),
	.FLASH_Q(FLASH_Q),
	.in_data(flash_data),
	.in_data_latch(flash_latch),
	.in_data_continue(flash_continue),
	.out_data(flash_out_data),
	.wren(record_enable),
	.rden(playback_enable),
	.ready_out(flash_ready)
);

//Flash controller state machine
parameter STATE_IDLE = 0;
parameter STATE_REC_PROGRAM = 1;
parameter STATE_REC_TIMER_INIT = 2;
parameter STATE_REC_TIMER = 3;
parameter STATE_PB_WAIT_READ = 4;
parameter STATE_PB_WAIT = 5;
parameter STATE_PB_COMMAND = 6;
parameter STATE_PB_DATA = 7;

reg [3:0] state, next_state;
reg [31:0] timer, timer_shift;
reg save_timer, just_recorded_timer;
reg wait_ctr_clear, wait_ctr_incr;
reg clear_timer_flag;
reg first_round_flag;
reg [8:0] wait_ctr;

always @(posedge rst or posedge clk) begin

	if(rst) begin
		timer <= `SD 32'd0;
		first_round_flag <= `SD 1'b1;
		state <= `SD STATE_IDLE;
	end else begin
		state <= `SD next_state;

		//Base all timing off of first command, not boot-up time
		if(~first_round_flag)
			timer <= `SD timer + 1;
		if((record_enable & fifo_out_valid) | (playback_enable & flash_ready))
			first_round_flag <= `SD 1'b0;

		if(wait_ctr_clear)
			wait_ctr <= `SD 0;
		else if(wait_ctr_incr) begin
			wait_ctr <= `SD wait_ctr + 1;
			timer_shift <= `SD {timer_shift[23:0], flash_out_data};
		end

		if(save_timer) begin
			just_recorded_timer <= `SD 1'b1;
			timer_shift <= `SD timer;
		end else if(clear_timer_flag) begin
			just_recorded_timer <= `SD 1'b0;
		end
	end
end

always @* begin
	next_state = state;
	flash_data = 8'h00;
	flash_latch = 1'b0;
	flash_continue = 1'b0;
	out_data_strobe = 1'b0;
	wait_ctr_clear = 1'b1;
	wait_ctr_incr = 1'b0;
	save_timer = 1'b0;
	clear_timer_flag = 1'b0;
	fifo_out_latch = 1'b0;

	case(state)
		STATE_IDLE: begin
			if(record_enable)
				next_state = STATE_REC_PROGRAM;
			else if(playback_enable)
				next_state = STATE_PB_COMMAND;
		end

		STATE_REC_PROGRAM: begin
			flash_data = fifo_out_uart_data;
			flash_latch = flash_ready & fifo_out_valid;
			fifo_out_latch = flash_ready & fifo_out_valid;
			if(flash_latch)
				clear_timer_flag = 1'b1;
			if(fifo_out_valid && fifo_out_bus_idle && ~just_recorded_timer) begin
				flash_latch = 1'b0;
				fifo_out_latch = 1'b0;
				next_state = STATE_REC_TIMER_INIT;
			end
		end

		STATE_REC_TIMER_INIT: begin
			save_timer = 1'b1;
			next_state = STATE_REC_TIMER;
		end

		STATE_REC_TIMER: begin
			flash_data = timer_shift[31:24];
			flash_latch = flash_ready;
			wait_ctr_clear = 1'b0;
			wait_ctr_incr = flash_ready;
			if(flash_ready && wait_ctr == 3)
				next_state = STATE_REC_PROGRAM;
		end

		STATE_PB_WAIT_READ: begin
			wait_ctr_clear = 1'b0;
			wait_ctr_incr = flash_ready;
			flash_latch = flash_ready;
			if(flash_ready && wait_ctr == 3)
				next_state = STATE_PB_WAIT;
		end

		STATE_PB_WAIT: begin
			if(timer > timer_shift)
				next_state = STATE_PB_COMMAND;
		end
		
		STATE_PB_COMMAND: begin
			out_data_strobe = flash_ready;
			flash_latch = flash_ready;
			if(flash_ready)
				next_state = STATE_PB_DATA;
		end

		STATE_PB_DATA: begin
			out_data_strobe = flash_ready;
			flash_latch = flash_ready;
			if(ice_bus_idle)
				next_state = STATE_PB_WAIT_READ;
		end
	endcase
end

endmodule
