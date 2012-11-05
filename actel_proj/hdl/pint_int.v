module pint_int(
	input clk,
	input reset,
	output reg busy,
	
	//Controller logic signals
	input tx_req_latch,
	input tx_cmd_type,
	input [39:0] tx_data,
	input [2:0] tx_num_bytes,
	
	output rx_latch,
	output [2:0] rx_num_bytes,
	output reg [39:0] rx_data,

	//PINT signals
	output PINT_WRREQ,
	output PINT_WRDATA,
	output PINT_CLK,
	output PINT_RESETN,
	output reg PINT_RDREQ,
	input PINT_RDRDY,
	input PINT_RDDATA
);

parameter BAUD_DIV = 8; //TODO: What does this need to be set to???

//For now, I'm just going to assume that the RESETN signal works by itself
assign PINT_RESETN = ~reset;

reg pint_rdrdy2, pint_rdrdy1;
reg tx_in_progress, rx_in_progress;
reg [40:0] tx_data_latched;
reg [2:0] tx_num_bytes_latched;
reg [15:0] baud_ctr;
reg [5:0] rx_bit_count;
reg [5:0] tx_bit_count;
reg pint_clk_mute, pint_clk_int;

assign rx_num_bytes = rx_bit_count[5:3];
assign PINT_WRDATA = tx_data_latched[40];
assign PINT_CLK = (pint_clk_mute) ? 1'b0 : pint_clk_int;

assign busy = (tx_in_progress | rx_in_progress);
wire baud_tick = (baud_ctr == BAUD_DIV-1);

always @(posedge clk) begin
	//Sync logic for PINT_RDRDY signal
	pint_rdrdy1 <= PINT_RDRDY;
	pint_rdrdy2 <= pint_rdrdy1;
	PINT_RDDREQ <= 1'b0;
	rx_latch <= 1'b0;

	if(reset) begin
		tx_in_progress <= 1'b0;
		rx_in_progress <= 1'b0;
		baud_ctr <= 16'd0;
		pint_clk_int <= 1'b0;
		pint_clk_mute <= 1'b0;
		PINT_WRREQ <= 1'b0;
	end else begin
		//Default behavior is to let the PINT clock run
		baud_ctr <= baud_ctr + 1;
		if(baud_tick ) begin
			baud_ctr <= 0;
			pint_clk_int <= ~pint_clk_int;
		end
		
		//Read data back on PINT_RDDATA line, framed by PINT_RDREQ
		if(rx_in_progress) begin
			PINT_RDREQ <= 1'b1;
			if(baud_tick && pint_clk_int == 1'b0) begin
				//Rising edge of generated clock, shift in the received data
				rx_data[39:1] <= rx_data[38:0];
				rx_data[0] <= PINT_RDDATA;
				rx_bit_count <= rx_bit_count + 1;
			end
				
			//We end when the PINT_RDRDY line says we're done (goes low...)
			else if(baud_tick && pint_clk_int == 1'b1 && ~pint_rdrdy2) begin
				rx_in_progress <= 1'b0;
				rx_latch <= 1'b1;
			end
		end
			
		//Transmit data on PINT_WRDATA line, framed by WRREQ
		else if(tx_in_progress) begin
			if(baud_tick && pint_clk_int == 1'b0) begin
				PINT_WRREQ <= 1'b1;
			end 
			
			else if(baud_tick && pint_clk_int == 1'b1) begin
				//Falling edge of generated clock
				rx_data_latched[40:1] <= tx_data_latched[39:0];
				
				//Unmute clock after command bit has gone through
				pint_clk_mute <= 1'b0;
				
				//Check to see if we're done sending all the bytes
				tx_bit_count <= tx_bit_count + 1;
				if(tx_bit_count[5:3] == tx_num_bytes_latched) begin
					PINT_WRREQ <= 1'b0;
					tx_in_progress <= 1'b0;
				end
			end
		end
			
		//Wait for either the controller to initiate a write or the PINT to initiate an interrupt
		else begin
			baud_ctr <= 16'd0;
			rx_bit_count <= 6'd0;
			if(pint_rdrdy2) begin
				rx_in_progress <= 1'b1;
			end else if(tx_req_latch) begin
				tx_in_progress <= 1'b1;
				tx_data_latched <= tx_data;
				tx_num_bytes_latched <= {tx_cmd_type, tx_num_bytes};
				pint_clk_mute <= 1'b1;
				tx_bit_count <= 1;
			end
		end
	end
end

endmodule
