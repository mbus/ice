module m3_ice_top(
    input SYS_CLK,
    input [4:1] PB, //These are active-low!
    //input [4:1] DIP_SW,
    output [4:1] LED,
	
	output M3_0P6_SW,
	output M3_1P2_SW,
	output M3_VBATT_SW,

    input USB_UART_TXD,
    output USB_UART_RXD,
	
	inout POR_PAD,
	
	inout PMU_SCL,
	inout PMU_SDA,

    output FPGA_PINT_RESETN,
    output FPGA_PINT_RDREQ,
    input FPGA_PINT_RDDATA,
    input FPGA_PINT_RDRDY,
    output FPGA_PINT_CLK,
    output FPGA_PINT_WRDATA,
    output FPGA_PINT_WRREQ,
	
	output SCL_PU,
    output SDA_PU,
	output SPARE_PU,
    output SDA_PD,
    output SCL_PD,
	output SPARE_PD,
    output SCL_TRI,
    output SDA_TRI,
	output SPARE_TRI,
    input SCL_DISCRETE_BUF,
    input SDA_DISCRETE_BUF,
	input SPARE_DISCRETE_BUF,
	
	inout [23:0] GPIO
	
	//input FPGA_IO[1:0]

    /*input FPGA_IO[23:0],
    input FPGA_SPI_TXD,
    input FPGA_SPI_CLKOUT,
    input FPGA_SPI_FSSOUT,
    input FPGA_SPI_RXD,

    */
);

wire reset, reset_button, por_n;
assign reset = reset_button | (~por_n);

//Stupid Actel-specific global clock buffer assignment...
wire SYS_CLK_BUF;
CLKINT cb1(SYS_CLK_BUF, SYS_CLK);

debounce_ms db0(
	.clk_in(SYS_CLK_BUF),
	.db_in(~PB[1]),
	.db_out(reset_button)
);

por r1(
	.clk(SYS_CLK_BUF),
	.PAD(POR_PAD),
	.reset(por_n)
);

ice_bus ic1(
	.reset(reset),
	.clk(SYS_CLK_BUF),
	
	.PB(PB[4:1]),
	
	.PMU_SCL(PMU_SCL),
	.PMU_SDA(PMU_SDA),

	.USB_UART_TXD(USB_UART_TXD),
	.USB_UART_RXD(USB_UART_RXD),

	.PINT_WRREQ(FPGA_PINT_WRREQ),
	.PINT_WRDATA(FPGA_PINT_WRDATA),
	.PINT_CLK(FPGA_PINT_CLK),
	.PINT_RESETN(FPGA_PINT_RESETN),
	.PINT_RDREQ(FPGA_PINT_RDREQ),
	.PINT_RDRDY(FPGA_PINT_RDRDY),
	.PINT_RDDATA(FPGA_PINT_RDDATA),
	
	.SCL_PU(SCL_PU),
    .SDA_PU(SDA_PU),
	.SPARE_PU(SPARE_PU),
    .SDA_PD(SDA_PD),
    .SCL_PD(SCL_PD),
	.SPARE_PD(SPARE_PD),
    .SCL_TRI(SCL_TRI),
    .SDA_TRI(SDA_TRI),
	.SPARE_TRI(SPARE_TRI),
    .SCL_DISCRETE_BUF(SCL_DISCRETE_BUF),
    .SDA_DISCRETE_BUF(SDA_DISCRETE_BUF),
	.SPARE_DISCRETE_BUF(SPARE_DISCRETE_BUF),
	
	.GPIO(GPIO),
	
	.M3_VBATT_SW(M3_VBATT_SW),
	.M3_1P2_SW(M3_1P2_SW),
	.M3_0P6_SW(M3_0P6_SW),
	
	//.SCL_DIG(FPGA_IO[0]),
	//.SDA_DIG(FPGA_IO[1]),
	.SCL_DIG(1'b0),
	.SDA_DIG(1'b0),

	.debug(LED[4:1])
);

endmodule
