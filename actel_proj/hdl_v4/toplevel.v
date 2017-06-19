module m3_ice_top(
	input SYS_CLK,
	input [4:1] PB, //These are active-low!
	//input [4:1] DIP_SW,
	output [4:1] LED,
	inout [5:0] USER,
	
	output M3_0P6_SW,
	output M3_1P2_SW,
	output M3_VBATT_SW,

	input USB_UART_TXD,
	output USB_UART_RXD,
	
	inout POR_PAD,
	
	inout PMU_SCL,
	inout PMU_SDA,

	output FPGA_MB_DOUT,
	output FPGA_MB_COUT,
	input FPGA_MB_DIN,
	input FPGA_MB_CIN,
	
	output FPGA_MB_EDI,
	output FPGA_MB_EMO,
	output FPGA_MB_ECI,


	inout [23:0] GPIO
	
	//input FPGA_IO[1:0]

    /*input FPGA_IO[23:0],
    input FPGA_SPI_TXD,
    input FPGA_SPI_CLKOUT,
    input FPGA_SPI_FSSOUT,
    input FPGA_SPI_RXD,

    */
);

//TODO: Take this out...
/*assign FPGA_MB_DOUT = FPGA_MB_DIN;
assign FPGA_MB_COUT = FPGA_MB_CIN;*/

wire reset, reset_button, por;
wire reset_sync;

//Stupid Actel-specific global clock buffer assignment...
wire SYS_CLK_BUF;
`ifdef SIM_FLAG
	assign SYS_CLK_BUF = SYS_CLK;
	assign reset = ~PB[1];
`else
	CLKINT cb1(SYS_CLK_BUF, SYS_CLK);
	assign reset = reset_button | por;
`endif

debounce_ms db0(
	.clk_in(SYS_CLK_BUF),
	.db_in(~PB[1]),
	.db_out(reset_button)
);

por r1(
	.clk(SYS_CLK_BUF),
	.PAD(POR_PAD),
    .PB_RESET(PB[1]),
	.reset(por)
);


wire clk = SYS_CLK_BUF;

sync sync0(
    .clk(clk),
    .async(reset), 
    .sync(reset_sync)
    );

ice_bus ic1(
	.reset(reset_sync),
	.clk(clk),
	
	.PB(PB[4:1]),
	
	.PMU_SCL(PMU_SCL),
	.PMU_SDA(PMU_SDA),

	.USB_UART_TXD(USB_UART_TXD),
	.USB_UART_RXD(USB_UART_RXD),

	.FPGA_MB_DOUT(FPGA_MB_DOUT),
	.FPGA_MB_COUT(FPGA_MB_COUT),
	.FPGA_MB_DIN(FPGA_MB_DIN),
	.FPGA_MB_CIN(FPGA_MB_CIN),
	
	.FPGA_MB_EDI(FPGA_MB_EDI),
	.FPGA_MB_EMO(FPGA_MB_EMO),
	.FPGA_MB_ECI(FPGA_MB_ECI),

	.USER(USER),
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
