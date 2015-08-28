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

reg [3:0] state, next_state;

always @(posedge rst or posedge clk) begin
	if(rst) begin
		state <= `SD STATE_IDLE;
	end else begin
		state <= `SD next_state;
	end
end

always @* begin
	next_state = state;
	ready_out = 1'b0;
	flash_data = 8'h00;
	flash_latch = 1'b0;
	flash_continue = 1'b0;

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
			flash_latch = flash_out_latch;
			if(flash_out_latch)
				next_state = STATE_WR_INIT3;
		end

		STATE_WR_INIT3: begin
			flash_data = FLASH_CMD_RDSR;
			flash_latch = flash_out_latch;
			flash_continue = (flash_byte_ctr < 3);
			if(flash_out_latch && ~flash_continue) begin
				flash_latch = 1'b0;
				if(flash_rd_data[0] == 1'b0) begin
					next_state = STATE_WR_PROGRAM;
			end
		end

		STATE_WR_PROGRAM: begin
			if(flash_byte_ctr == 1)
				flash_data = cur_flash_addr[2];
			else if(flash_byte_ctr == 2)
				flash_data = cur_flash_addr[1];
			else if(flash_byte_ctr == 3)
				flash_data = cur_flash_addr[0];
			flash_latch = flash_out_latch;
			flash_continue = 1'b1;
			if(flash_out_latch && flash_byte_ctr == 3)
				next_state = STATE_WR_WAIT;
		end

		STATE_WR_WAIT: being
			ready_out = flash_out_latch && (flash_byte_ctr < 260);
			flash_data = in_data;
			flash_latch = flash_out_latch & in_data_latch;
			flash_continue = (flash_byte_ctr < 260);
			if(flash_out_latch && flash_byte_ctr == 260)
				next_state = STATE_WR_INIT3;
		end

		STATE_RD_INIT: begin
			flash_data = FLASH_CMD_FAST_READ;
			flash_latch = 1'b1;
			flash_continue = 1'b1;
			next_state = STATE_RD_ADDR;
		end

		STATE_RD_ADDR: begin
			//3 bytes addr, 1 byte dummy
			flash_latch = flash_out_latch;
			flash_continue = 1'b1;
			if(flash_out_latch && flash_byte_ctr == 4)
				next_state = STATE_RD_DATA;
		end

		STATE_RD_DATA: begin
			flash_continue = 1'b1;
			flash_latch = flash_out_latch;
			ready_out = flash_ready;
		end
	endcase
end

endmodule
