`timescale 1ns/1ps

`include "include/ice_def.v"

`define MEM_SIZE 200_000
`define SIM_FLAG

module tb_ice();

integer file, n, i, j, k, l;

integer mem_idx_0, mem_idx_1;
reg [7:0] mem_0[0:`MEM_SIZE];
reg [7:0] mem_1[0:`MEM_SIZE];

reg clk;
reg reset;


wire ice_dout, ice_cout, ice_din, ice_cin;

wire uart_0_rxd;
wire uart_0_rx_latch;
wire uart_0_txd;
reg uart_0_tx_latch;
wire uart_0_empty;
uart u0(
	.clk(clk),
	.reset(reset),
	.baud_div(16'd174),
	.rx_in(uart_0_rxd),
	.rx_latch(uart_0_rx_latch),
	.tx_out(uart_0_txd),
	.tx_latch(uart_0_tx_latch),
	.tx_data(mem_0[mem_idx_0]),
	.tx_empty(uart_0_empty)
);

wire flash_c, flash_d, flash_s, flash_w, flash_q;

M25P05A f0(
    .c(flash_c),
    .data_in(flash_d),
    .s(flash_s),
    .w(flash_w),
    .hold(1'b1),
    .data_out(flash_q)
);

m3_ice_top t0(
	.SYS_CLK(clk),
	.PB({3'b111,~reset}),
    .DIP_SW({2'b10}),
	
    .FLASH_D(flash_d),
	.FLASH_C(flash_c),
	.FLASH_CSn(flash_s),
	.FLASH_WPn(flash_w),
	.FLASH_Q(flash_q),

	.USB_UART_RXD(uart_0_rxd),
	.USB_UART_TXD(uart_0_txd),

	.FPGA_MB_DOUT(ice_dout),
	.FPGA_MB_COUT(ice_cout),
	.FPGA_MB_DIN(ice_din),
	.FPGA_MB_CIN(ice_cin)
);

wire uart_1_rxd;
reg uart_1_rx_latch;
reg [7:0] uart_1_rx_data;
wire uart_1_txd;
reg uart_1_tx_latch;
wire uart_1_empty;
uart u1(
	.clk(clk),
	.reset(reset),
	.baud_div(16'd174),
	.rx_in(uart_1_rxd),
	.rx_latch(uart_1_rx_latch),
	.rx_data(uart_1_rx_data),
	.tx_out(uart_1_txd),
	.tx_latch(uart_1_tx_latch),
	.tx_data(mem_1[mem_idx_1]),
	.tx_empty(uart_1_empty)
);
m3_ice_top t1(
	.SYS_CLK(clk),
	.PB({3'b111,~reset}),

	.USB_UART_RXD(uart_1_rxd),
	.USB_UART_TXD(uart_1_txd),

	.FPGA_MB_DOUT(ice_din),
	.FPGA_MB_COUT(ice_cin),
	.FPGA_MB_DIN(ice_dout),
	.FPGA_MB_CIN(ice_cout)
);

task send_command_0;
	input reg [80*8:1] file_name;
	integer resp_hack;
	begin

	$display("Start %s", file_name);

	file = $fopen(file_name,"r");
	@ (posedge clk);
	n = $fread(mem_0, file);
	@(posedge clk);
	for(mem_idx_0 = 0; mem_idx_0 < n; mem_idx_0=mem_idx_0+1) begin
		`SD uart_0_tx_latch = 1'b1;
		@(posedge clk);
		`SD uart_0_tx_latch = 1'b0;
		@(posedge clk);
		@(posedge uart_0_empty);
	end
	$fclose(file);

	while (1'b1) begin
		resp_hack = 0;
		for (k=0; k<2000; k=k+1) begin
			if (uart_0_rx_latch) begin
				resp_hack = 1;
			end
			@(posedge clk);
		end

		if (resp_hack == 0) begin
			break;
		end
	end

	$display("End   %s", file_name);
	end
endtask

task send_command_1;
	input reg [80*8:1] file_name;
	integer resp_hack;
	begin

	$display("Start %s", file_name);

	file = $fopen(file_name,"r");
	@ (posedge clk);
	n = $fread(mem_1, file);
	@(posedge clk);
	for(mem_idx_1 = 0; mem_idx_1 < n; mem_idx_1=mem_idx_1+1) begin
		`SD uart_1_tx_latch = 1'b1;
		@(posedge clk);
		`SD uart_1_tx_latch = 1'b0;
		@(posedge clk);
		@(posedge uart_1_empty);
	end
	$fclose(file);

	while (1'b1) begin
		resp_hack = 0;
		for (k=0; k<2000; k=k+1) begin
			if (uart_1_rx_latch) begin
				resp_hack = 1;
			end
			@(posedge clk);
		end

		if (resp_hack == 0) begin
			break;
		end
	end

	$display("End   %s", file_name);
	end
endtask

initial
begin
	//Initialize the clock...
	clk = 0;
	reset = 0;

	// top-level resets
	uart_0_tx_latch = 1'b0;
	uart_1_tx_latch = 1'b0;

	//Wait for the reset circuitry to kick in...
	@ (posedge clk);
	@ (posedge clk);
	@ (posedge clk);
	`SD reset = 1;
	@ (posedge clk);
	@ (posedge clk);
	`SD reset = 0;
	@ (posedge clk);
	@ (posedge clk);
	@ (posedge clk);
	
	//Wait for stuff to happen...
	for(i = 0; i < 300000; i=i+1) begin
		@(posedge clk);
	end

	for (l=0; l<50; l=l+1) begin
		send_command_0("C:\\Users\\Ben Kempke\\Documents\\repos\\ice\\actel_proj\\test_sequences\\power_1p2_on");
	end

	/*send_command_1("../test_sequences/mbus_set_master_on");
	send_command_1("../test_sequences/mbus_set_master_off");
	send_command_1("../test_sequences/mbus_set_snoop_match_all_short");
	send_command_1("../test_sequences/mbus_set_snoop_match_all_long");

	send_command_0("../test_sequences/mbus_set_master_on");
	send_command_0("../test_sequences/mbus_send_message_SNS_config_bits");*/

	//Wait for stuff to happen...
	for(i = 0; i < 300000; i=i+1) begin
		@(posedge clk);
	end

	//$stop;
	$finish;
end

always #12500 clk = ~clk;

endmodule // testbench
