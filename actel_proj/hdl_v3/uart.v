`include "include/ice_def.v"

//----------------------------------------------------------------------------------------
// Design Name : uart 
// File Name   : uart.v
// Function    : Simple UART
// Coder       : Deepak Kumar Tala (w/ significant annotations and modifications from Ben Kempke)
// Pulled from : http://www.asic-world.com/examples/verilog/uart.html on 11/1/2012
//----------------------------------------------------------------------------------------
module uart (
	// Port declarations
	input reset             ,//Reset signal for entire UART module (active high)

	input clk               ,//Clock corresponding to TX baudrate
	input [7:0] baud_div   ,

	input rx_in             ,//UART RX line
	output reg tx_out       ,//UART TX line

	input tx_latch          ,//TX Data Latch
	input [7:0] tx_data     ,//8-bit TX Data
	output reg tx_empty     ,//Ready for new TX Data

	output reg [7:0] rx_data,//8-bit RX Data
	output reg rx_latch      //RX Data ready line (high for one rxclk cycle)
);

// Internal Variables 
reg [7:0] tx_reg;
reg [3:0] tx_cnt;
reg [3:0] rx_cnt;
reg [15:0] rx_sample_cnt;
reg [15:0] tx_sample_cnt;
reg rx_d1;
reg rx_d2;
reg rx_busy;

// UART RX Logic 
always @ (posedge clk) begin
	if (reset) begin
		rx_data       <= `SD 0; 
		rx_sample_cnt <= `SD 0;
		rx_cnt        <= `SD 0;
		rx_latch      <= `SD 0;
		rx_d1         <= `SD 1;
		rx_d2         <= `SD 1;
		rx_busy       <= `SD 0;
	end else begin
		// Synchronize the asynch signal
		rx_d1 <= `SD rx_in;
		rx_d2 <= `SD rx_d1;
		rx_latch <= `SD 0;
		// Check if just received start of frame
		if (!rx_busy && !rx_d2) begin
			rx_busy       <= `SD 1;
			rx_sample_cnt <= `SD 1;
			rx_cnt        <= `SD 0;
		end
		// Start of frame detected, Proceed with rest of data
		if (rx_busy) begin
			rx_sample_cnt <= `SD rx_sample_cnt + 1;
			// Logic to sample at middle of data (or just at the beginning since really this shouldn't be a big deal with bouncing...)
			if (rx_sample_cnt == 1) begin
				if ((rx_d2 == 1) && (rx_cnt == 0)) begin
					rx_busy <= `SD 0;
				end else begin
					rx_cnt <= `SD rx_cnt + 1; 
					// Start storing the rx data
					if (rx_cnt > 0 && rx_cnt < 9) begin
						rx_data[rx_cnt - 1] <= `SD rx_d2;
					end
					if (rx_cnt == 9) begin
						rx_busy <= `SD 0;
						// Check if End of frame received correctly
						if (rx_d2 == 1) begin
							rx_latch     <= `SD 1;
						end
					end
				end
			end else if(rx_sample_cnt == baud_div-1) begin
				rx_sample_cnt <= `SD 0;
			end
		end 
	end
end

// UART TX Logic
always @ (posedge clk) begin
	if (reset) begin
		tx_reg        <= `SD 0;
		tx_empty      <= `SD 1;
		tx_sample_cnt <= `SD 0;
		tx_out        <= `SD 1;
		tx_cnt        <= `SD 0;
	end else begin
		if (!tx_empty) begin
			tx_sample_cnt <= `SD tx_sample_cnt + 1;
			if(tx_sample_cnt == baud_div-1) begin
				tx_sample_cnt <= `SD 0;
				tx_cnt <= `SD tx_cnt + 1;
				if (tx_cnt == 0) begin
					tx_out <= `SD 0;
				end
				if (tx_cnt > 0 && tx_cnt < 9) begin
					tx_out <= `SD tx_reg[tx_cnt -1];
				end
				if (tx_cnt == 9) begin
					tx_out <= `SD 1;
					tx_cnt <= `SD 0;
					tx_empty <= `SD 1;
				end
			end
		end else if (tx_latch) begin
			tx_reg   <= `SD tx_data;
			tx_empty <= `SD 0;
			tx_sample_cnt <= `SD 0;
		end
	end
end

endmodule
