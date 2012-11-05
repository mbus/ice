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

ice_controller ic1(
	.reset(reset),
	.clk(SYS_CLK),

	.USB_UART_TXD(USB_UART_TXD),
	.USB_UART_RXD(USB_UART_RXD),

	.PINT_WRREQ(PINT_WRREQ),
	.PINT_WRDATA(PINT_WRDATA),
	.PINT_CLK(PINT_CLK),
	.PINT_RESETN(PINT_RESETN),
	.PINT_RDREQ(PINT_RDREQ),
	.PINT_RDRDY(PINT_RDRDY),
	.PINT_RDDATA(PINT_RDDATA),

	.debug(LED[8:1])
);

endmodule
