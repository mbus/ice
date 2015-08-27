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

//Both write protect and hold are not needed in this implementation
assign FLASH_WPn = 1'b1;
assign FLASH_HOLDn = 1'b1;

assign out_data = flash_out_data;

//FIFO used to buffer incoming data from 
wire fifo_out_bus_idle, fifo_out_latch, fifo_out_valid;
wire [7:0] fifo_out_uart_data;
fifo #(9,9) ff(
	.clk(clk),
	.reset(rst),
	.in_data({ice_bus_idle,uart_data}),
	.in_latch(uart_data_strobe),
	.out_data({fifo_out_bus_idle,fifo_out_uart_data}),
	.out_data_latch(fifo_out_latch),
	.out_data_valid(fifo_out_valid)
);

//Enumerated flash commands
parameter FLASH_CMD_WREN = 8'h06;
parameter FLASH_CMD_WRDI = 8'h04;
parameter FLASH_CMD_RDID = 8'h9F;
parameter FLASH_CMD_RDSR = 8'h05;
parameter FLASH_CMD_WRSR = 8'h01;
parameter FLASH_CMD_READ = 8'h03;
parameter FLASH_CMD_FAST_READ = 8'h0B;
parameter FLASH_CMD_PP = 8'h02;
parameter FLASH_CMD_SE = 8'hD8;
parameter FLASH_CMD_BE = 8'hC7;
parameter FLASH_CMD_DP = 8'hB9;
parameter FLASH_CMD_RES = 8'hAB;

//Flash controller state machine
parameter STATE_IDLE = 0;
reg [3:0] state, next_state;
reg [31:0] timer;

always @(posedge rst or posedge clk) begin

	if(rst) begin
		timer <= `SD 32'd0;
		state <= `SD STATE_IDLE;
	end else begin
		if(flash_continue) begin
			if(flash_latch)
				flash_byte_counter <= `SD flash_byte_counter + 1;
		end else begin
			flash_byte_counter <= `SD 9'h00;
		end
	end
end

always @* begin
	next_state = state;
	flash_data = 8'h00;
	flash_latch = 1'b0;
	flash_continue = 1'b0;
	out_data_strobe = 1'b0;

	case(state)
		STATE_IDLE: begin
			if(record_enable)
				next_state = STATE_REC_INIT;
			else if(playback_enable)
				next_state = STATE_PB_IDLE;
		end

		STATE_REC_INIT: begin
			//Need to start off by erasing the chip
			// (requires a WREN command first)
			flash_data = FLASH_CMD_WREN;
			flash_latch = 1'b1;
			next_state = STATE_REC_INIT2;
		end

		STATE_REC_INIT2: begin
			flash_data = FLASH_CMD_BE;
			flash_latch = flash_done;
			if(flash_done)
				next_state = STATE_REC_INIT3;
		end

		STATE_REC_INIT3: begin
			flash_data = FLASH_CMD_RDSR;
			flash_latch = flash_done;
			flash_continue = (flash_byte_ctr < 3);
			if(flash_done && ~flash_continue) begin
				flash_latch = 1'b0;
				if(flash_rd_data[0] == 1'b0) begin
					next_state = STATE_REC_PROGRAM;
			end
		end

		STATE_REC_PROGRAM: begin
			flash_data = FLASH_CMD_PP;
			flash_latch = 1'b1;
			flash_continue = 1'b1;
			next_state = STATE_REC_PROGRAM_ADDR;
		end

		STATE_REC_PROGRAM_ADDR: begin
			if(flash_byte_ctr == 1)
				flash_data = cur_flash_addr[2];
			else if(flash_byte_ctr == 2)
				flash_data = cur_flash_addr[1];
			else if(flash_byte_ctr == 3)
				flash_data = cur_flash_addr[0];
			flash_latch = flash_done;
			flash_continue = 1'b1;
			if(flash_done && flash_byte_ctr == 3)
				next_state = STATE_REC_WAIT;
		end

		STATE_REC_WAIT: begin
			flash_data = fifo_out_uart_data;
			flash_latch = flash_done & fifo_out_valid;
			flash_continue = (flash_byte_ctr < 260);
			if(flash_done && flash_byte_ctr == 260)
				next_state = STATE_REC_INIT3;
		end

		STATE_PB_IDLE: begin
			flash_data = FLASH_CMD_FAST_READ;
			flash_latch = 1'b1;
			flash_continue = 1'b1;
			next_state = STATE_PB_ADDR;
		end

		STATE_PB_ADDR: begin
			//3 bytes addr, 1 byte dummy
			flash_latch = flash_done;
			flash_continue = 1'b1;
			if(flash_done && flash_byte_ctr = 4)
				next_state = STATE_PB_DATA;
		end

		STATE_PB_DATA: begin
			out_data_strobe = flash_done;
			flash_continue = 1'b1;
			flash_latch = flash_done;
		end
end

endmodule
