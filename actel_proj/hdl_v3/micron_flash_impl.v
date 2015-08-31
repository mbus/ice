`include "include/ice_def.v"

module micron_flash_impl(
	input clk,
	input rst,

	//Interface to flash chip
	output FLASH_D,
	output FLASH_C,
	output FLASH_CSn,
	output FLASH_WPn,
	output FLASH_HOLDn,
	input FLASH_Q,
	
	input [7:0] in_data,
	input in_data_latch,
	input in_data_continue,
	output [7:0] out_data,

	input wren,
	input rden,

	output reg ready_out
	
);

//Both write protect and hold are not needed in this implementation
assign FLASH_WPn = 1'b1;
assign FLASH_HOLDn = 1'b1;

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

reg [7:0] flash_data;
reg flash_latch;
reg flash_continue;

spi_master sm1(
	.clk(clk),
	.rst(rst),

	.spi_mosi(FLASH_D),
	.spi_miso(FLASH_Q),
	.spi_clk(FLASH_C),
	.spi_csn(FLASH_CSn),

	.in_latch(flash_latch),
	.in_data(flash_data),
	.in_continue(flash_continue),
	.out_data(out_data),
	.out_done_latch(flash_out_latch),
	.out_ready(flash_ready)
);

//State machine states
parameter STATE_IDLE = 0;
parameter STATE_WR_INIT = 1;
parameter STATE_WR_INIT2 = 2;
parameter STATE_WR_INIT3 = 3;
parameter STATE_WR_INIT4 = 4;
parameter STATE_WR_PROGRAM = 5;
parameter STATE_WR_PROGRAM2 = 6;
parameter STATE_WR_WAIT = 7;
parameter STATE_RD_INIT = 8;
parameter STATE_RD_ADDR = 9;
parameter STATE_RD_DATA = 10;

reg [3:0] state, next_state;
reg [8:0] flash_byte_ctr;
reg [23:0] cur_flash_addr;
reg flash_incr_addr;

always @(posedge rst or posedge clk) begin
	if(rst) begin
		state <= `SD STATE_IDLE;
		flash_byte_ctr <= `SD 0;
		cur_flash_addr <= `SD 0;
	end else begin
		state <= `SD next_state;

		if(flash_continue & flash_latch) begin
				if(flash_byte_ctr < 9'h1ff)
					flash_byte_ctr <= `SD flash_byte_ctr + 1;
		end else if(flash_latch) begin
				flash_byte_ctr <= `SD 0;
		end

		if(flash_incr_addr)
			cur_flash_addr <= `SD cur_flash_addr + 9'h100;
	end
end

always @* begin
	next_state = state;
	ready_out = 1'b0;
	flash_data = 8'h00;
	flash_latch = 1'b0;
	flash_continue = 1'b0;
	flash_incr_addr = 1'b0;

	case(state)
		STATE_IDLE: begin
			if(wren)
				next_state = STATE_WR_INIT;
			else if(rden)
				next_state = STATE_RD_INIT;
		end

		STATE_WR_INIT: begin
			//Need to start off by erasing the chip
			// (requires a WREN command first)
			flash_data = FLASH_CMD_WREN;
			flash_latch = 1'b1;
			next_state = STATE_WR_INIT2;
		end
		
 
		STATE_WR_INIT2: begin
			flash_data = FLASH_CMD_BE;
			flash_latch = flash_ready;
			if(flash_ready)
				next_state = STATE_WR_INIT3;
		end

		STATE_WR_INIT3: begin
			flash_data = FLASH_CMD_RDSR;
			flash_latch = flash_ready;
			flash_continue = (flash_byte_ctr < 3) || out_data[0];
			if(flash_ready && ~flash_continue) begin
				next_state = STATE_WR_INIT4;
			end
		end
		
		STATE_WR_INIT4: begin
			flash_data = FLASH_CMD_WREN;
			flash_latch = flash_ready;
			if(flash_ready)
				next_state = STATE_WR_PROGRAM;
		end
		
		STATE_WR_PROGRAM: begin
			//Must wait for last extra byte to go through
			flash_data = FLASH_CMD_PP;
			flash_latch = flash_ready;
			flash_continue = 1'b1;
			if(flash_ready) 
				next_state = STATE_WR_PROGRAM2;
		end

		STATE_WR_PROGRAM2: begin
			if(flash_byte_ctr == 1)
				flash_data = cur_flash_addr[23:16];
			else if(flash_byte_ctr == 2)
				flash_data = cur_flash_addr[15:8];
			else if(flash_byte_ctr == 3)
				flash_data = cur_flash_addr[7:0];
			flash_latch = flash_ready;
			flash_continue = 1'b1;
			if(flash_ready && flash_byte_ctr == 3)
				next_state = STATE_WR_WAIT;
		end

		STATE_WR_WAIT: begin
			ready_out = flash_ready;
			flash_data = in_data;
			flash_latch = in_data_latch;
			flash_continue = (flash_byte_ctr < 259);
			if(flash_latch && flash_byte_ctr == 259) begin
				flash_incr_addr = 1'b1;
				next_state = STATE_WR_INIT3;
			end
		end

		STATE_RD_INIT: begin
			flash_data = FLASH_CMD_FAST_READ;
			flash_latch = 1'b1;
			flash_continue = 1'b1;
			next_state = STATE_RD_ADDR;
		end

		STATE_RD_ADDR: begin
			//3 bytes addr, 1 byte dummy
			flash_latch = flash_ready;
			flash_continue = 1'b1;
			if(flash_ready && flash_byte_ctr == 5)
				next_state = STATE_RD_DATA;
		end

		STATE_RD_DATA: begin
			flash_continue = 1'b1;
			flash_latch = in_data_latch;
			ready_out = flash_ready;
		end
	endcase
end

endmodule
