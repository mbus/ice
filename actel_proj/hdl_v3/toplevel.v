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

wire reset, reset_button, por_n;
assign reset = reset_button | (~por_n);

//Stupid Actel-specific global clock buffer assignment...
wire SYS_CLK_BUF;
CLKINT cb1(SYS_CLK_BUF, SYS_CLK);

wire [31:0] mbus_rxaddr;
wire [31:0] mbus_rxdata;
assign GPIO[12] = mbus_rxaddr[0] | mbus_rxaddr[31];
assign GPIO[13] = mbus_rxdata[0] | mbus_rxdata[31];
assign GPIO[23:14] = 10'd0;
 
mbus_ctrl_layer_wrapper mclw1
  (
    .CLK_EXT(SYS_CLK),
    .CLKIN(FPGA_MB_CIN),
    .RESETn(~reset),
    .DIN(FPGA_MB_DIN),
    .CLKOUT(FPGA_MB_COUT),
    .DOUT(FPGA_MB_DOUT),
    .TX_ADDR(32'hdeadbeef),
    .TX_DATA(32'hdeadbeef),
    .TX_PEND(GPIO[0]),
    .TX_REQ(GPIO[1]),
    .TX_PRIORITY(GPIO[2]),
    .TX_ACK(GPIO[3]),
    .RX_ADDR(mbus_rxaddr),
    .RX_DATA(mbus_rxdata),
    .RX_REQ(GPIO[4]),
    .RX_ACK(GPIO[5]),
    .RX_BROADCAST(GPIO[6]),
    .RX_FAIL(GPIO[7]),
    .RX_PEND(GPIO[8]),
    .TX_FAIL(GPIO[9]),
    .TX_SUCC(GPIO[10]),
    .TX_RESP_ACK(GPIO[11])
   );

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

	.FPGA_MB_DOUT(FPGA_MB_DOUT),
	.FPGA_MB_COUT(FPGA_MB_COUT),
	.FPGA_MB_DIN(FPGA_MB_DIN),
	.FPGA_MB_CIN(FPGA_MB_CIN),
	
	.FPGA_MB_EDI(FPGA_MB_EDI),
	.FPGA_MB_EMO(FPGA_MB_EDO),
	.FPGA_MB_ECI(FPGA_MB_ECI),

	.USER(USER),
	//TODO: Put this back in...
    //.GPIO(GPIO[23:14]),
	
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