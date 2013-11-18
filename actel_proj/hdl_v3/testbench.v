`timescale 1ns/1ps

`include "include/ice_def.v"

`define MEM_SIZE 200_000
`define SIM_FLAG

module tb_ice();

integer file, n, i;
reg [7:0] mem[0:`MEM_SIZE];
reg [80*8:1] file_name;

reg clk;
reg reset;

wire uart_line;
reg uart_latch;
wire uart_empty;

//Modules
uart u0(
	.clk(clk),
	.reset(reset),
	.baud_div(16'd174),
	.rx_in(1'b1),
	.tx_out(uart_line),
	.tx_latch(uart_latch),
	.tx_data(mem[i]),
	.tx_empty(uart_empty)
);

m3_ice_top t0(
	.SYS_CLK(clk),
	.PB({3'b111,~reset}),

	.USB_UART_TXD(uart_line)
);

initial
begin
	//Initialize the clock...
	clk = 0;
	reset = 0;

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

	file_name = "data.bin";
	file = $fopen(file_name,"r");
	n = $fread(file, mem[0]);
	for(i = 0; i < n; i=i+1) begin
		`SD uart_latch = 1'b1;
		@(posedge clk);
		`SD uart_latch = 1'b0;
		@(posedge clk);
		@(posedge uart_empty);
	end
	$fclose(file);

	//Wait for stuff to happen...
	for(i = 0; i < 1000; i=i+1) begin
		@(posedge clk);
	end

	$stop;
end

always #1250 clk = ~clk;

endmodule // testbench
