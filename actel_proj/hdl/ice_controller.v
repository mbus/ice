module ice_controller (
	input reset,
	input clk,

	//USB to UART signals
	input USB_UART_TXD,
	output USB_UART_RXD,

	//PINT signals
	output PINT_WRREQ,
	output PINT_WRDATA,
	output PINT_CLK,
	output PINT_RESETN,
	output PINT_RDREQ,
	input PINT_RDRDY,
	input PINT_RDDATA,

	//Discrete I2C Interface signals
	input SCL_DISCRETE_BUF,
	output SCL_PD,
	output SCL_PU,
	output SCL_TRI,
	input SDA_DISCRETE_BUF,
	output SDA_PD,
	output SDA_PU,
	output SDA_TRI,
	
	//PINT Debug signals
	input SCL_DIG,
	input SDA_DIG,

	//Debug signals
	output [7:0] debug
);

//UART module
wire [7:0] uart_rx_data;
reg [7:0] uart_tx_data;
reg uart_tx_latch;
wire uart_tx_empty;
wire uart_rx_latch;
// 20MHz -> 115200 baud -> DIVIDE_FACTOR = 173.6
uart #(174) u1(
	.reset(reset),
	.clk(clk),
	.rx_in(USB_UART_TXD),
	.tx_out(USB_UART_RXD),
	.tx_latch(uart_tx_latch),
	.tx_data(uart_tx_data),
	.tx_empty(uart_tx_empty),
	.rx_data(uart_rx_data),
	.rx_latch(uart_rx_latch)
);

wire cd_is_hex;
wire [3:0] cd_hex_decode;
wire cd_is_cmd;
wire [3:0] cd_cmd;
wire cd_is_eol;
character_decoder cd1(
	.in_char(uart_rx_data),
	.in_char_valid(uart_rx_latch),
	.is_hex_char(cd_is_hex),
	.hex_decode(cd_hex_decode),
	.is_cmd(cd_is_cmd),
	.cmd(cd_cmd),
	.is_eol(cd_is_eol)
);

//PINT interface module
wire pint_busy;
reg pint_tx_req_latch;
reg pint_tx_char_latch;
reg pint_tx_cmd_type;
reg [3:0] hex_sr;
wire pint_rx_latch;
wire [7:0] pint_rx_data;
wire pint_rx_req;
wire [7:0] pint_fifo_data;
reg pint_fifo_latch;
wire pint_fifo_valid;
fifo #(8,4) f00(
	.clk(clk),
	.reset(reset),
	.in(pint_rx_data),
	.in_latch(pint_rx_latch),
	.out(pint_fifo_data),
	.out_latch(pint_fifo_latch),
	.out_valid(pint_fifo_valid)
);

pint_int pi1(
	.reset(reset),
	.clk(clk),
	.busy(pint_busy),
	.tx_req(pint_tx_req_latch),
	.tx_cmd_type(pint_tx_cmd_type),
	.tx_char({hex_sr,cd_hex_decode}),
	.tx_char_latch(pint_tx_char_latch),
	.rx_latch(pint_rx_latch),
	.rx_data(pint_rx_data),
	.rx_req(pint_rx_req),
	.PINT_WRREQ(PINT_WRREQ),
	.PINT_WRDATA(PINT_WRDATA),
	.PINT_CLK(PINT_CLK),
	.PINT_RESETN(PINT_RESETN),
	.PINT_RDREQ(PINT_RDREQ),
	.PINT_RDRDY(PINT_RDRDY),
	.PINT_RDDATA(PINT_RDDATA)
);

//Discrete interface modules
wire [7:0] disc_rx_char;
wire disc_rx_char_latch;
wire disc_rx_req;
wire [7:0] disc_fifo_data;
wire disc_fifo_valid;
reg disc_fifo_latch;
reg disc_tx_latch, disc_tx_req;
reg disc_addr_latch, disc_addr_req;
fifo #(8,4) f01(
	.clk(clk),
	.reset(reset),
	.in(disc_rx_char),
	.in_latch(disc_rx_char_latch),
	.out(disc_fifo_data),
	.out_latch(disc_fifo_latch),
	.out_valid(disc_fifo_valid)
);

discrete_int di01(
	.reset(reset),
	.clk(clk),

	.SCL_DISCRETE_BUF(SCL_DISCRETE_BUF),
	.SCL_PD(SCL_PD),
	.SCL_PU(SCL_PU),
	.SCL_TRI(SCL_TRI),
	
	.SDA_DISCRETE_BUF(SDA_DISCRETE_BUF),
	.SDA_PD(SDA_PD),
	.SDA_PU(SDA_PU),
	.SDA_TRI(SDA_TRI),

	.addr_match_char({hex_sr,cd_hex_decode}),
	.addr_match_latch(disc_addr_latch),
	.addr_match_reset(disc_addr_req),

	.tx_char({hex_sr,cd_hex_decode}),
	.tx_char_latch(disc_tx_latch),
	.tx_req(disc_tx_req),

	.rx_char(disc_rx_char),
	.rx_char_latch(disc_rx_char_latch),
	.rx_req(disc_rx_req)
);

//Character encoder to hex-encode FIFO data
reg cur_interface;
reg which_hex_char;
wire [7:0] ce_in = (cur_interface) ? disc_fifo_data : pint_fifo_data;
wire [7:0] ce_out;
wire ce_valid = (cur_interface) ? disc_fifo_valid : pint_fifo_valid;
character_encoder ce0(
	.char_in(ce_in),
	.which_hex_char(which_hex_char),
	
	.out(ce_out)
);


//DEBUG:
//assign debug = uart_rx_data;
assign debug = {SCL_DISCRETE_BUF, SCL_PD, SCL_PU, SCL_TRI, SDA_DISCRETE_BUF, SDA_PD, SDA_PU, SDA_TRI};
//assign debug = {uart_rx_latch, uart_rx_data[6:0]};
//assign debug = {PINT_WRREQ,PINT_WRDATA,PINT_CLK,PINT_RESETN,PINT_RDREQ,PINT_RDRDY,PINT_RDDATA};
//assign debug = {PINT_RDRDY,PINT_WRREQ,PINT_WRDATA,PINT_CLK,PINT_RESETN,SCL_DIG,SDA_DIG};

//Controller state machine
parameter STATE_IDLE = 0;
parameter STATE_PINT_SEND0 = 1;
parameter STATE_PINT_SEND1 = 2;
parameter STATE_PINT_SEND2 = 3;
parameter STATE_DISC_SEND = 4;
parameter STATE_DISC_ADDR_SEND = 5;

reg [3:0] tx_state;
reg [3:0] next_tx_state;
reg [3:0] last_cmd;
reg [3:0] sr_count;
reg sr_clear;
reg last_is_cmd;
reg shift_in_hex_data, pad_sr_data;

//Sequential logic
always @(posedge clk) begin
	last_cmd <= 4'd0;
	last_is_cmd <= 1'b0;

	if(reset) begin
		tx_state <= STATE_IDLE;
	end else begin
		tx_state <= next_tx_state;
		//Commands automatically push state to IDLE
		if(cd_is_cmd) begin
			last_cmd <= cd_cmd;
			last_is_cmd <= 1'b1;
			tx_state <= STATE_IDLE;
		end

		if(shift_in_hex_data || pad_sr_data) begin
			hex_sr <= cd_hex_decode;
			sr_count <= sr_count + 4'd1;
		end else if(sr_clear) begin
			sr_count <= 4'd0;
		end
	end
end

//Next-state logic (For TX state machine)
//TODO: This is ugly... should replace with shared bus...
always @* begin
	next_tx_state = tx_state;
	shift_in_hex_data = 1'b0;
	pad_sr_data = 1'b0;
	pint_tx_cmd_type = 1'b0;
	pint_tx_char_latch = 1'b0;
	pint_tx_req_latch = 1'b0;
	sr_clear = 1'b0;
	disc_tx_latch = 1'b0;
	disc_tx_req = 1'b0;

	case(tx_state)
		//Idle state listens for specific command identifiers
		STATE_IDLE: begin
			if(last_is_cmd) begin
				if(last_cmd == 4'd0 || last_cmd == 4'd1)
					next_tx_state = STATE_PINT_SEND0;
				else if(last_cmd == 4'd2) 
					next_tx_state = STATE_DISC_SEND;
				else if(last_cmd == 4'd3)
					next_tx_state = STATE_DISC_ADDR_SEND;
			end
		end

		//These three states take care of all outgoing PINT requests
		STATE_PINT_SEND0: begin
			if(cd_is_hex) begin
				shift_in_hex_data = 1'b1;
				pint_tx_char_latch = sr_count[0];
			end else if(cd_is_eol) begin
				next_tx_state = STATE_PINT_SEND1;
			end
		end

		STATE_PINT_SEND1: begin
			if(last_cmd == 4'd1) begin
				pint_tx_cmd_type = 1'b1;
			end
			if(sr_count[3:1] > 0) begin
				pint_tx_req_latch = 1'b1;
			end
			sr_clear = 1'b1;
			next_tx_state = STATE_IDLE;//TODO: Does this need to take into account the pint busy signal???
		end
		
		STATE_DISC_SEND: begin
			if(cd_is_hex) begin
				shift_in_hex_data = 1'b1;
				disc_tx_latch = sr_count[0];
			end else if(cd_is_eol) begin
				sr_clear = 1'b1;
				disc_tx_latch = 1'b1;
				disc_tx_req = 1'b1;
				next_tx_state = STATE_IDLE;
			end
		end

		STATE_DISC_ADDR_SEND: begin
			if(cd_is_hex) begin
				shift_in_hex_data = 1'b1;
				disc_addr_latch = sr_count[0];
			end else if(cd_is_eol) begin
				sr_clear = 1'b1;
				disc_addr_latch = 1'b1;
				disc_addr_req = 1'b1;
				next_tx_state = STATE_IDLE;
			end
		end
	endcase
end

/*********************
 * RX State Machine
 *********************/
`define STATE_RX_IDLE 0
`define STATE_RX0 1
`define STATE_RX1 2
`define STATE_RX_END 3

reg [3:0] rx_state;
reg [3:0] next_rx_state;
reg latch_interface, which_interface;
reg switch_hex_char;
//reg which_hex_char;
always @* begin
	next_rx_state = rx_state;
	uart_tx_latch = 1'b0;
	uart_tx_data = 8'd0;
	disc_fifo_latch = 1'b0;
	pint_fifo_latch = 1'b0;
	latch_interface = 1'b0;
	which_interface = 1'b0;
	switch_hex_char = 1'b0;
	
	case(rx_state)
		`STATE_RX_IDLE: begin
			latch_interface = 1'b1;
			if(disc_rx_req) begin
				which_interface = 1'b1;
				next_rx_state = `STATE_RX0;
			end else if(pint_rx_latch) begin
				which_interface = 1'b0;
				next_rx_state = `STATE_RX0;
			end
		end
		
		`STATE_RX0: begin
			uart_tx_latch = uart_tx_empty;
			uart_tx_data = (cur_interface) ? 8'h63 : 8'h61;
			if(uart_tx_empty)
				next_rx_state = `STATE_RX1;
		end
		
		`STATE_RX1: begin //TODO: At some point should make this a little more robust (what if multiple sequences come in over I2C before one is finished transferring over-the-line?)
			uart_tx_latch = uart_tx_empty & ce_valid;
			uart_tx_data = ce_out;
			switch_hex_char = uart_tx_latch;
			if(cur_interface)
				disc_fifo_latch = uart_tx_latch & which_hex_char;
			else
				pint_fifo_latch = uart_tx_latch & which_hex_char;
			if(!ce_valid)
				next_rx_state = `STATE_RX_END;
		end

		`STATE_RX_END: begin
			uart_tx_latch = uart_tx_empty;
			uart_tx_data = 8'h0a;
			if(uart_tx_empty)
				next_rx_state = `STATE_RX_IDLE;
		end
	endcase
end

always @(posedge clk) begin
	if(reset) begin
		rx_state <= `STATE_RX_IDLE;
		cur_interface <= 1'b0;
		which_hex_char <= 1'b0;
	end else begin
		if(latch_interface)
			cur_interface <= which_interface;
		if(switch_hex_char)
			which_hex_char <= ~which_hex_char;
		rx_state <= next_rx_state;
	end
end

endmodule

