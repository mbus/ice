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
	input [15:0] baud_div   ,

	input rx_in             ,//UART RX line
	output reg tx_out       ,//UART TX line

	input tx_latch          ,//TX Data Latch
	input [7:0] tx_data     ,//8-bit TX Data
	output reg tx_empty     ,//Ready for new TX Data

	output reg [7:0] rx_data,//8-bit RX Data
	output reg rx_latch      //RX Data ready line (high for one rxclk cycle)
);

parameter NUM_SYNC=5;

// Internal Variables 
reg [7:0] tx_reg;
reg [3:0] tx_cnt;
reg [3:0] rx_cnt;
reg [15:0] rx_sample_cnt;
reg [15:0] tx_sample_cnt;
reg [NUM_SYNC-1:0] rx_sync;
wire rx_d = rx_sync[NUM_SYNC-1];
reg rx_busy;
reg rx_error;

// UART RX Logic 
always @ (posedge clk) begin
	if (reset) begin
		rx_data       <= `SD 0; 
		rx_sample_cnt <= `SD 0;
		rx_cnt        <= `SD 0;
		rx_latch      <= `SD 0;
		rx_busy       <= `SD 0;
        rx_error      <=     0;
		rx_sync	      <= `SD {{NUM_SYNC}{1'b1}};
	end else begin
		// Synchronize the asynch signal
		rx_sync[0] <= `SD rx_in;
		rx_sync[NUM_SYNC-1:1] <= `SD rx_sync[NUM_SYNC-2:0];
		rx_latch <= `SD 0;

        // check if in an error state
        // why can't this use a state machine like normal verilog?
		if (rx_error)
        begin
            if (rx_in == 1)
            begin
                rx_error <= 0;
            end

		// Check if just received start of frame
        end else if (!rx_busy && !rx_d) begin
			rx_busy       <= `SD 1;
			rx_sample_cnt <= `SD 1;
			rx_cnt        <= `SD 0;

		// Start of frame detected, Proceed with rest of data
        end else if (rx_busy) begin
			rx_sample_cnt <= `SD rx_sample_cnt + 1;
			// Logic to sample at middle of data
			if (rx_sample_cnt == baud_div[15:1]) begin
				if ((rx_d == 1) && (rx_cnt == 0)) begin
					rx_busy <= `SD 0;
				end else begin
					rx_cnt <= `SD rx_cnt + 1; 
					// Start storing the rx data
					if (rx_cnt > 0 && rx_cnt < 9) begin
						rx_data[rx_cnt - 1] <= `SD rx_d;
					end
					if (rx_cnt == 9) begin
                        rx_busy <= `SD 0;
						// Check if End of frame received correctly
						if (rx_d == 1) begin
							rx_latch     <= `SD 1;
                        // ANDREW: go to error state if baud mismatch
						end else begin
                            rx_error <= 1;
                        end
					end
				end
			end else if(rx_sample_cnt == baud_div-1) begin
				rx_sample_cnt <= `SD 0;
			end //if/else if  rx_sample 
        end // rx_busy
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
