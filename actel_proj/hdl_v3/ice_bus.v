module ice_bus (
	input reset,
	input clk,
	
	input [4:1] PB,
	inout [5:0] USER,

	//USB to UART signals
	input USB_UART_TXD,
	output USB_UART_RXD,
	
	//PMU I2C signals
	inout PMU_SDA,
	inout PMU_SCL,

	//MBus signals
	output FPGA_MB_DOUT,
	output FPGA_MB_COUT,
	input FPGA_MB_DIN,
	input FPGA_MB_CIN,

	//Fake-GOC signals
	output FPGA_MB_EDI,
	output FPGA_MB_EMO,
	output FPGA_MB_ECI,
	
	//PINT Debug signals
	input SCL_DIG,
	input SDA_DIG,
	
	//GPIO pads
	inout [23:0] GPIO,
	
	//GOC pad
	output GOC_PAD,
	
	//M3 Power switch pads
	output M3_0P6_SW,
	output M3_1P2_SW,
	output M3_VBATT_SW,

	//Debug signals
	output [3:0] debug
);

parameter NUM_DEV = 7;

//User lines are current not used as there are no daughterboards which have been made
assign USER = 6'd0;

//UART module
wire [7:0] uart_rx_data, uart_tx_data;
wire uart_tx_latch, uart_rx_latch;
wire uart_tx_empty;
// 20MHz -> 3 Mbaud -> DIVIDE_FACTOR = 6.6666
uart #(173) u1(
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

//Global event counter is used for tagging messages in time
wire mbus_ctr_incr, gpio_ctr_incr;
wire [7:0] global_counter;
global_event_counter gec1(
	.clk(clk),
	.rst(reset),
	
	.ctr_incr(mbus_ctr_incr | gpio_ctr_incr),
	.counter_out(global_counter)
);

//Main bus connections
wire ma_generate_nak;
wire [7:0] ma_data, ma_addr;
wire ma_data_valid, ma_frame_valid;
wire [7:0] sl_data;
wire [NUM_DEV-1:0] sl_arb_request, sl_arb_grant;
wire sl_overflow, sl_data_latch;
ice_bus_controller #(NUM_DEV) ice1(
	.clk(clk),
	.rst(reset),

	.rx_char(uart_rx_data),
	.rx_char_valid(uart_rx_latch),
	.tx_char(uart_tx_data),
	.tx_char_valid(uart_tx_latch),
	.tx_char_ready(uart_tx_empty),

	//Immediate NAKs have their own controller =)
	.generate_nak(ma_generate_nak),
	.evt_id(),
	
	//Master-driven bus (data & control)
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),
	
	//Bus controller outputs (data & control)
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request),
	.sl_arb_grant(sl_arb_grant),
	.sl_data_latch(sl_data_latch)
);

//Basics module responds to basic requests (query info, etc)
wire [7:0] basics_debug;
wire [7:0] i2c_speed;
wire [15:0] i2c_addr;
wire [21:0] goc_speed;
wire goc_polairty;
wire [23:0] gpio_level;
wire [23:0] gpio_direction;
wire mbus_master_mode, mbus_cpu_mode;
basics_int bi0(
	.clk(clk),
	.rst(reset),

	//Immediates from bus controller
	.generate_nak(ma_generate_nak),

	//Master input bus
	.ma_data(ma_data),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[0]),
	.sl_arb_grant(sl_arb_grant[0]),
	.sl_data_latch(sl_data_latch),
	
	//I2C settings
	.i2c_speed(i2c_speed),
	.i2c_addr(i2c_addr),
	
	//GOC settings
	.goc_speed(goc_speed),
	.goc_polarity(goc_polarity),
	
	//GPIO settings
	.gpio_read(GPIO),
	.gpio_level(gpio_level),
	.gpio_direction(gpio_direction),
	
	//M3 Power Switch Settings
	.M3_VBATT_SW(M3_VBATT_SW),
	.M3_1P2_SW(M3_1P2_SW),
	.M3_0P6_SW(M3_0P6_SW),
	
	.debug()
);

//TODO: REMOVE ME!
assign sl_arb_request[2:1] = 2'b00;
/*mbus_layer_wrapper_ice mb0(
	.clk(clk),
	.reset(reset),
	
	.DIN(FPGA_MB_DIN),
	.DOUT(FPGA_MB_DOUT),
	.CIN(FPGA_MB_CIN),
	.COUT(FPGA_MB_COUT),

	.MASTER_NODE(mbus_master_mode),
	.CPU_LAYER(mbus_cpu_mode),

	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[2:1]),
	.sl_arb_grant(sl_arb_grant[2:1]),
	.sl_data_latch(sl_data_latch),
	
	//Global counter for 'time-tagging'
	.global_counter(global_counter),
	.incr_ctr(mbus_ctr_incr)
);*/

/*
//Discrete interface module controls all of the discrete interface signals
discrete_int di0(
	.clk(clk),
	.reset(reset),
	
	.SCL_DISCRETE_BUF(SCL_DISCRETE_BUF),
	.SCL_PD(SCL_PD),
	.SCL_PU(SCL_PU),
	.SCL_TRI(SCL_TRI),
	
	.SDA_DISCRETE_BUF(SDA_DISCRETE_BUF),
	.SDA_PD(SDA_PD),
	.SDA_PU(SDA_PU),
	.SDA_TRI(SDA_TRI),
	
	//I2C settings
	.i2c_speed(i2c_speed),
	.i2c_addr(i2c_addr),
	
	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[2:1]),
	.sl_arb_grant(sl_arb_grant[2:1]),
	.sl_data_latch(sl_data_latch),
	
	//Global counter for 'time-tagging'
	.global_counter(global_counter),
	.incr_ctr(disc_ctr_incr),
	
	.debug(basics_debug)
);*/

//GOC interface flashes pretty lights
goc_int gi0(
	.clk(clk),
	.reset(reset),
	
	.GOC_PAD(GOC_PAD),
	
	.goc_speed(goc_speed),
	.goc_polarity(goc_polarity),
	
	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[3]),
	.sl_arb_grant(sl_arb_grant[3]),
	.sl_data_latch(sl_data_latch)
);

//EIN interface provides GOC-like interface but through direct 3-wire connection
ein_int ei0(
	.clk(clk),
	.reset(reset),
	
	.EMO_PAD(FPGA_MB_EMO),
	.EDI_PAD(FPGA_MB_EDI),
	.ECI_PAD(FPGA_MB_ECI),
	
	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[6]),
	.sl_arb_grant(sl_arb_grant[6]),
	.sl_data_latch(sl_data_latch)
);

//GPIO interface 
gpio_int gi1(
	.clk(clk),
	.reset(reset),
	
	.GPIO(GPIO),
	
	.gpio_level(gpio_level),
	.gpio_direction(gpio_direction),

	//Slave output bus
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[4]),
	.sl_arb_grant(sl_arb_grant[4]),
	.sl_data_latch(sl_data_latch),
	
	//Global counter for 'time-tagging'
	.global_counter(global_counter),
	.incr_ctr(gpio_ctr_incr)
);

//PMU interface
wire [7:0] pmu_debug;
pmu_int pi0(
	.clk(clk),
	.reset(reset),
	
	.pmu_scl(PMU_SCL),
	.pmu_sda(PMU_SDA),
	
	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[5]),
	.sl_arb_grant(sl_arb_grant[5]),
	.sl_data_latch(sl_data_latch),
	
	.debug(pmu_debug)
);

	
/*//PINT interface module
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
);*/

//DEBUG:
//assign debug = uart_rx_data;
//assign debug = {SCL_DISCRETE_BUF, SCL_PD, SCL_PU, SCL_TRI, SDA_DISCRETE_BUF, SDA_PD, SDA_PU, SDA_TRI};
assign debug = (~PB[4]) ? {FPGA_MB_EDI, FPGA_MB_EMO, FPGA_MB_ECI} : 
               (~PB[3]) ? {pmu_debug[2:0], PMU_SCL, PMU_SDA} : 
			   (~PB[2]) ? {sl_arb_request, sl_arb_grant[0], sl_data[0]} : {GOC_PAD, 1'b0, ma_data_valid, ma_frame_valid};
//assign debug = {PINT_WRREQ,PINT_WRDATA,PINT_CLK,PINT_RESETN,PINT_RDREQ,PINT_RDRDY,PINT_RDDATA};
//assign debug = {PINT_RDRDY,PINT_WRREQ,PINT_WRDATA,PINT_CLK,PINT_RESETN,SCL_DIG,SDA_DIG};


endmodule
