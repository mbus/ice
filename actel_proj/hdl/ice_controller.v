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

	//Debug signals
	output [7:0] debug
);

//UART module
wire [7:0] uart_rx_data;
wire [7:0] uart_tx_data;
wire uart_tx_latch;
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

//PINT interface module
wire pint_busy;
reg pint_tx_req_latch;
reg pint_tx_cmd_type;
wire [39:0] pint_tx_data;
wire [2:0] pint_tx_num_bytes;
wire pint_rx_latch;
wire [2:0] pint_rx_num_bytes;
wire [39:0] pint_rx_data;
pint_int pi1(
	.reset(reset),
	.clk(clk),
	.busy(pint_busy),
	.tx_req_latch(pint_tx_req_latch),
	.tx_cmd_type(pint_tx_cmd_type),
	.tx_data(pint_tx_data),
	.tx_num_bytes(pint_tx_num_bytes),
	.rx_latch(pint_rx_latch),
	.rx_data(pint_rx_data),
	.rx_num_bytes(pint_rx_num_bytes),
	.PINT_WRREQ(PINT_WRREQ),
	.PINT_WRDATA(PINT_WRDATA),
	.PINT_CLK(PINT_CLK),
	.PINT_RESETN(PINT_RESETN),
	.PINT_RDREQ(PINT_RDREQ),
	.PINT_RDRDY(PINT_RDRDY),
	.PINT_RDDATA(PINT_RDDATA)
);

//DEBUG: For now, just display what's been decoded from the UART on the debug lines
assign debug = uart_rx_data;

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

//Controller state machine
`define STATE_IDLE 0
`define STATE_PINT_SEND0 1
`define STATE_PINT_SEND1 2

reg [5:0] state;
reg [5:0] next_state;
reg [3:0] last_cmd;
reg [39:0] hex_sr;
reg [3:0] sr_count;
reg [3:0] valid_sr_count;
reg sr_clear;
reg last_is_cmd;
reg shift_in_hex_data;

assign pint_tx_data = hex_sr;
assign pint_tx_num_bytes = valid_sr_count[3:1];

//Sequential logic
always @(posedge clk) begin
	last_cmd <= 4'd0;
	last_is_cmd <= 1'b0;

	if(reset) begin
		state <= `STATE_IDLE;
	end else begin
		state <= next_state;
		//Commands automatically push state to IDLE
		if(cd_is_cmd) begin
			last_cmd <= cd_cmd;
			last_is_cmd <= 1'b1;
			state <= `STATE_IDLE;
		end

		if(shift_in_hex_data || pad_sr_data) begin
			hex_sr <= {hex_sr[35:0], cd_hex_decode};
			sr_count <= sr_count + 4'd1;
			if(shift_in_hex_data) valid_sr_count <= sr_count;
		end else if(sr_clear) begin
			sr_count <= 4'd0;
		end
	end
end

//Next-state logic
always @* begin
	next_state = state;
	shift_in_hex_data = 1'b0;
	pint_tx_cmd_type = 1'b0;
	pint_tx_req_latch = 1'b0;
	sr_clear = 1'b0;

	case(state)
		//Idle state listens for specific command identifiers
		`STATE_IDLE: begin
			if(last_is_cmd && (last_cmd == 4'd0 || last_cmd == 4'd1)) begin
				next_state = `STATE_PINT_SEND0;
			end
		end

		//These two states take care of all outgoing PINT requests
		`STATE_PINT_SEND0: begin
			if(cd_is_hex) begin
				shift_in_hex_data = 1'b1;
			end else if(cd_is_eol) begin
				next_state = `STATE_PINT_SEND1;
			end
		end
		
		`STATE_PINT_SEND1: begin
			pad_sr_data = 1'b1;
			if(sr_count == 4'd8) begin
				next_state = `STATE_PINT_SEND2;
			end
		end

		`STATE_PINT_SEND2: begin
			if(last_cmd == 4'd1) begin
				pint_tx_cmd_type = 1'b1;
			end
			if(sr_count[3:1] > 0) begin
				pint_tx_req_latch = 1'b1;
			end
			sr_clear = 1'b1;
			next_state = `STATE_PINT_SEND0;//TODO: Does this need to take into account the pint busy signal???
		end
	endcase
end

endmodule

