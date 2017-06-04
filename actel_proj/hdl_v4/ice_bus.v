`include "include/ice_def.v"

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

// Create a syncronized reset signal
reg reset_syn0;
reg reset_syn1;

//only place posedge reset allowed
always @ (posedge clk or posedge reset) begin
    if (reset)  begin
        reset_syn0 <= `SD 1'b1;
        reset_syn1 <= `SD 1'b1;
    end
    else begin
        reset_syn0 <= `SD 1'b0;
        reset_syn1 <= `SD reset_syn0;
    end
end







//User lines are current not used as there are no daughterboards which have been made
assign USER[5:3] = 3'd0;
//Direct assign of USB_UART_TDX and USB_UART_RXD to debug header
assign USER[2] = USB_UART_RXD;
assign USER[1] = USB_UART_TXD;
//Direct assignment of GOC signal to debug header
assign USER[0] = debug[3];

//UART module
wire [7:0] uart_rx_data, uart_tx_data;
wire uart_tx_latch, uart_rx_latch;
wire uart_tx_empty;
wire [15:0] uart_baud_div;
// 20MHz -> 3 Mbaud -> DIVIDE_FACTOR = 6.6666
// 20MHz -> 115200 -> DIVIDE_FACTOR = 173
// >= v0.4 - use 1MBaud
// 20MHZ -> 2MBaud -> DIVIDE_FACTOR = 10
uart u1(
	.reset(reset_syn1),
	.clk(clk),
	.baud_div(uart_baud_div),
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
	.rst(reset_syn1),
	
	.ctr_incr(mbus_ctr_incr | gpio_ctr_incr),
	.counter_out(global_counter)
);

//Main bus connections
wire ma_generate_nak;
wire [7:0] ma_data, ma_addr;
wire ma_data_valid2, ma_frame_valid;
wire [8:0] sl_data;
wire [8:0] sl_addr;
wire [8:0] sl_tail;
wire       sl_latch_tail;
wire [NUM_DEV-1:0] sl_arb_request, sl_arb_grant;
wire sl_overflow;
ice_bus_controller #(NUM_DEV) ice1(
	.clk(clk),
	.rst(reset_syn1),

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
	.ma_data_valid(ma_data_valid2),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),
	
	//Bus controller outputs (data & control)
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request),
	.sl_arb_grant(sl_arb_grant)
);

//Basics module responds to basic requests (query info, etc)
wire [7:0] basics_debug;
wire [7:0] i2c_speed;
wire [15:0] i2c_addr;
wire [31:0] goc_speed;
wire goc_polarity, goc_mode;
wire [23:0] gpio_level;
wire [23:0] gpio_direction;
wire [23:0] gpio_int_enable;
wire mbus_force_reset;
wire mbus_master_mode;
wire mbus_snoop_enabled;
wire mbus_tx_prio;
wire [19:0] mbus_long_addr;
wire  [3:0] mbus_short_addr_override;
wire [21:0] mbus_clk_div;
basics_int bi0(
	.clk(clk),
	.rst(reset_syn1),

	//Immediates from bus controller
	.generate_nak(ma_generate_nak),

	//Master input bus
	.ma_data(ma_data),
	.ma_data_valid(ma_data_valid2),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[0]),
	.sl_arb_grant(sl_arb_grant[0]),
	
	//I2C settings
	.i2c_speed(i2c_speed),
	.i2c_addr(i2c_addr),
	
	//GOC settings
	.goc_speed(goc_speed),
	.goc_polarity(goc_polarity),
	.goc_mode(goc_mode),
	
	//GPIO settings
	.gpio_read(GPIO),
	.gpio_level(gpio_level),
	.gpio_direction(gpio_direction),
	.gpio_int_enable(gpio_int_enable),

	//MBus settings
	.mbus_force_reset(mbus_force_reset),
	.mbus_master_mode(mbus_master_mode),
	.mbus_snoop_enabled(mbus_snoop_enabled),
	.mbus_long_addr(mbus_long_addr),
	.mbus_short_addr_override(mbus_short_addr_override),
	.mbus_clk_div(mbus_clk_div),
	.mbus_tx_prio(mbus_tx_prio),
	
	//M3 Power Switch Settings
	.M3_VBATT_SW(M3_VBATT_SW),
	.M3_1P2_SW(M3_1P2_SW),
	.M3_0P6_SW(M3_0P6_SW),
	
	//UART settings
	.uart_baud_div(uart_baud_div),
	.uart_tx_empty(uart_tx_empty),
	
	.debug()
);

/* Need to reset the whole MBus node when starts/stops acting as the master
 * node, otherwise if nothing was plugged in, the input pins were floating
 * and it could be in a weird state. */

reg mbus_reset;
reg next_mbus_reset;
reg mbus_was_master;
reg next_mbus_was_master;


// this will delay the mbus_reset 1 cycle, but it will sync the various 
// reset signals comming into the block
always @ (posedge clk) begin
    if (reset_syn1) begin
        mbus_reset <= `SD 1'b1;
        mbus_was_master <= `SD 1'h0;
    end else begin
        mbus_reset <= `SD next_mbus_reset;
        mbus_was_master <= `SD next_mbus_was_master;
    end
end

always @* begin
    next_mbus_reset = 1'h0;
	next_mbus_was_master = mbus_was_master;

	if(mbus_was_master != mbus_master_mode) begin
        next_mbus_reset = 1'h1;
        next_mbus_was_master = mbus_master_mode;
	end else if ( mbus_force_reset  == 1'h1) begin
        next_mbus_reset = 1'h1;
    end
end



wire [3:0] mb_debug;
mbus_layer_wrapper_ice mb0(
	.clk(clk),
	.reset(mbus_reset),
	
	.DIN(FPGA_MB_DIN),
	.DOUT(FPGA_MB_DOUT),
	.CLKIN(FPGA_MB_CIN),
	.CLKOUT(FPGA_MB_COUT),

	.MASTER_NODE(mbus_master_mode),
	.mbus_snoop_enabled(mbus_snoop_enabled),
	.mbus_long_addr(mbus_long_addr),
	.mbus_short_addr_override(mbus_short_addr_override),
	.mbus_clk_div(mbus_clk_div),
	.mbus_tx_prio(mbus_tx_prio),

	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid2),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[2:1]),
	.sl_arb_grant(sl_arb_grant[2:1]),
	
	//Global counter for 'time-tagging'
	.global_counter(global_counter),
	.incr_ctr(mbus_ctr_incr),
	
	.debug(mb_debug)
);

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
	.ma_data_valid(ma_data_valid2),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[2:1]),
	.sl_arb_grant(sl_arb_grant[2:1]),
	
	//Global counter for 'time-tagging'
	.global_counter(global_counter),
	.incr_ctr(disc_ctr_incr),
	
	.debug(basics_debug)
);*/

//GOC interface flashes pretty lights
//TODO: Put GOC back in...
assign sl_arb_request[3] = 1'b0;
/*goc_int gi0(
	.clk(clk),
	.reset(reset_syn1),
	
	.GOC_PAD(GOC_PAD),
	
	.goc_speed(goc_speed),
	.goc_polarity(goc_polarity),
	
	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid2),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[3]),
	.sl_arb_grant(sl_arb_grant[3])
);*/

wire ein_emo, ein_edi, ein_eci;
assign GOC_PAD = (goc_mode) ? (ein_edi ^ goc_polarity) : goc_polarity;
assign FPGA_MB_EMO = (goc_mode) ? 1'b0 : ein_emo;
assign FPGA_MB_EDI = (goc_mode) ? 1'b0 : ein_edi;
assign FPGA_MB_ECI = (goc_mode) ? 1'b0 : ein_eci;

//EIN interface provides GOC-like interface but through direct 3-wire connection
ein_int ei0(
	.clk(clk),
	.reset(reset_syn1),
	
	.EMO_PAD(ein_emo),
	.EDI_PAD(ein_edi),
	.ECI_PAD(ein_eci),

	.goc_mode(goc_mode),
	.CLK_DIV(goc_speed),
	
	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid2),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[6]),
	.sl_arb_grant(sl_arb_grant[6])
);

//GPIO interface
//assign sl_arb_request[4] = 1'b0;
gpio_int gi1(
	.clk(clk),
	.reset(reset),
	
	.GPIO(GPIO),
	
	.gpio_level(gpio_level),
	.gpio_direction(gpio_direction),
	.gpio_int_enable(gpio_int_enable),

	//Slave output bus
	.sl_data(sl_data),
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_arb_request(sl_arb_request[4]),
	.sl_arb_grant(sl_arb_grant[4]),
	
	//Global counter for 'time-tagging'
	.global_counter(global_counter),
	.incr_ctr(gpio_ctr_incr)
);


//PMU interface
wire [7:0] pmu_debug;
pmu_int pi0(
	.clk(clk),
	.reset(reset_syn1),
	
	.pmu_scl(PMU_SCL),
	.pmu_sda(PMU_SDA),
	
	//Master input bus
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid2),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),

	//Slave output bus
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request[5]),
	.sl_arb_grant(sl_arb_grant[5]),
	
	.debug(pmu_debug)
);

/* removed code about a PINT interface */	
/* removed code about a Discrete interface */	

//DEBUG:
//assign debug = uart_rx_data;
//assign debug = {SCL_DISCRETE_BUF, SCL_PD, SCL_PU, SCL_TRI, SDA_DISCRETE_BUF, SDA_PD, SDA_PU, SDA_TRI};
assign debug = (~PB[4]) ? {FPGA_MB_CIN, FPGA_MB_DIN, USB_UART_TXD,USB_UART_RXD} :  
               (~PB[3]) ? {1'b0, FPGA_MB_EMO, FPGA_MB_EDI, FPGA_MB_ECI} : 
			   (~PB[2]) ? {FPGA_MB_COUT, FPGA_MB_DOUT, FPGA_MB_CIN, FPGA_MB_DIN} : 
			   (~PB[1]) ? {PMU_SCL, PMU_SDA} : {GOC_PAD, reset, FPGA_MB_CIN, FPGA_MB_DIN};
//assign debug = {PINT_WRREQ,PINT_WRDATA,PINT_CLK,PINT_RESETN,PINT_RDREQ,PINT_RDRDY,PINT_RDDATA};
//assign debug = {PINT_RDRDY,PINT_WRREQ,PINT_WRDATA,PINT_CLK,PINT_RESETN,SCL_DIG,SDA_DIG};


endmodule
