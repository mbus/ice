// Top-level Verilog module for M3 ICE Board
module m3_ice(
    input SYS_CLK,
    input [1:1] PB, //These are active-low!
    //input [4:1] DIP_SW,
    output [8:1] LED,

    input USB_UART_TXD,
    output USB_UART_RXD

    /*output FPGA_PINT_RESETN,
    output FPGA_PINT_RDREQ,
    input FPGA_PINT_RDDATA,
    input FPGA_PINT_RDRDY,
    output FPGA_PINT_CLK,
    output FPGA_PINT_WRDATA,
    output FPGA_PINT_WRREQ,

    input FPGA_IO[23:0],
    input FPGA_SPI_TXD,
    input FPGA_SPI_CLKOUT,
    input FPGA_SPI_FSSOUT,
    input FPGA_SPI_RXD,

    output SCL_PU,
    output SDA_PU,
    output SDA_PD,
    output SCL_PD,
    output SCL_TRI,
    output SDA_TRI,
    input SCL_DISCRETE_BUF,
    input SDA_DISCRETE_BUF*/
);

wire reset = ~PB[1];

//UART module
wire [7:0] uart_rx_data;
wire [7:0] uart_tx_data;
wire uart_tx_latch;
wire uart_tx_empty;
wire uart_rx_latch;
// 20MHz -> 115200 baud -> DIVIDE_FACTOR = 173.6
uart #(174) u1(
	.reset(reset),
	.clk(SYS_CLK),
	.rx_in(USB_UART_TXD),
	.tx_out(USB_UART_RXD),
	.tx_latch(uart_tx_latch),
	.tx_data(uart_tx_data),
	.tx_empty(uart_tx_empty),
	.rx_data(uart_rx_data),
	.rx_latch(uart_rx_latch)
);

//For now, we're just going to echo everything received and display the current byte on the LEDs
assign uart_tx_latch = uart_rx_latch;
assign uart_tx_data = uart_rx_data;
assign LED[8:1] = uart_rx_data;

endmodule
