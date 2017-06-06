///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: ice_mbus_tx.v
// File history:
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//
// Description: 
//
// <Description here>
//
// Targeted device: <Family::IGLOO> <Die::AGLN250V2> <Package::100 VQFP>
// Author: <Name>
//
/////////////////////////////////////////////////////////////////////////////////////////////////// 

`timescale 1ns/1ps

`include "include/ice_def.v"
`define SIM_FLAG

module ice_mbus_tx;

parameter SYSCLK_PERIOD = 50;// 20MHZ
//parameter SYSCLK_PERIOD = 5000;// 20MHZ

integer ice_0_dout_count;
integer ice_1_uart_rxd_count;

reg         clk;
reg         reset;

// UART PORTS
reg [7:0]   uart_0_tx_data;
reg         uart_0_tx_latch;
wire        uart_0_tx_empty;
wire [7:0]  uart_0_rx_data;
wire        uart_0_rx_latch;

wire        uart_0_rxd;
wire        uart_0_txd;

reg [7:0]   uart_1_tx_data;
reg         uart_1_tx_latch;
wire        uart_1_tx_empty;
wire [7:0]  uart_1_rx_data;
wire        uart_1_rx_latch;

wire        uart_1_rxd;
wire        uart_1_txd;

// ICE PORTS
wire        ice_0_cin;
wire        ice_0_din;
wire        ice_0_cout;
wire        ice_0_dout;

wire        ice_1_cin;
wire        ice_1_din;
wire        ice_1_cout;
wire        ice_1_dout;





//////////////////////////////////////////////////////////////////////
// Clock Driver
//////////////////////////////////////////////////////////////////////
always @(clk)
    #(SYSCLK_PERIOD / 2.0) clk <= !clk;

//
// Generate UART signals for input into m3_ice_top
//
uart uart0(
	.clk(clk),
	.reset(reset),
	.baud_div(16'd10),

	.rx_in(uart_0_rxd),
	.tx_out(uart_0_txd),

	.rx_latch(uart_0_rx_latch),
    .rx_data(uart_0_rx_data),

	.tx_latch(uart_0_tx_latch),
	.tx_data(uart_0_tx_data),
	.tx_empty(uart_0_tx_empty)
);

uart u1(
	.clk(clk),
	.reset(reset),
	.baud_div(16'd10),
	.rx_in(uart_1_rxd),
	.rx_latch(uart_1_rx_latch),
	.rx_data(uart_1_rx_data),
	.tx_out(uart_1_txd),
	.tx_latch(uart_1_tx_latch),
	.tx_data(uart_1_tx_data),
	.tx_empty(uart_1_tx_empty)
);


//////////////////////////////////////////////////////////////////////
// Instantiate Unit Under Test:  hdl_v4
//////////////////////////////////////////////////////////////////////

// Use LHS for delays in continuous assignment
assign #100 ice_0_din = ice_1_dout;
assign #100 ice_0_cin = ice_1_cout;

m3_ice_top ice_0(

    .SYS_CLK(clk),
	.PB({3'b111,~reset}),

    .USB_UART_TXD(uart_0_txd),
    .USB_UART_RXD(uart_0_rxd),

    .FPGA_MB_CIN(ice_0_cin),
    .FPGA_MB_DIN(ice_0_din),
    .FPGA_MB_COUT(ice_0_cout),
    .FPGA_MB_DOUT(ice_0_dout)
    
);

assign #100 ice_1_din = ice_0_dout;
assign #100 ice_1_cin = ice_0_cout;

m3_ice_top ice_1 (

    .SYS_CLK(clk),
	.PB({3'b111,~reset}),

    .USB_UART_TXD(uart_1_txd),
    .USB_UART_RXD(uart_1_rxd),

    .FPGA_MB_CIN(ice_1_cin),
    .FPGA_MB_DIN(ice_1_din),
    .FPGA_MB_COUT(ice_1_cout),
    .FPGA_MB_DOUT(ice_1_dout)
    
);

    always @(negedge ice_0_dout ) begin
        ice_0_dout_count = ice_0_dout_count + 1;
    end

    always @(negedge uart_1_rxd ) begin
        ice_1_uart_rxd_count = ice_1_uart_rxd_count + 1;
    end


    //
    // Stuff for parsing the string command into binary
    //
    function [3:0] asciiToNum;
        input [7:0] ascii;
        begin
        //$display("bad ascii %c: %h", ascii, ascii);
        //< '0'
        if (ascii < 8'h30) $fatal(1);
        // '0' - '9'
        else if ( ascii < 8'h3A) asciiToNum = ascii - 8'h30; // '0'
        // < 'A'
        else if (ascii < 8'h41) $fatal(1);
        else if (ascii < 8'h47) asciiToNum = ascii - 8'h41 + 8'd10; //'A'=10
        // < 'a'
        else if (ascii < 8'h61) $fatal(1);
        else if (ascii < 8'h67) asciiToNum = ascii - 8'h61 + 8'd10; //'a'=10
        // > 'f'
        else $fatal(1);
        end
    endfunction 

    function [7:0] toByteFromAscii;
        input [15:0] hex_string;
        begin
        //$display("ascii: %s", hex_string);
        toByteFromAscii[7:4] = asciiToNum(hex_string[15:8]);
        toByteFromAscii[3:0] = asciiToNum(hex_string[7:0]);
        //$display("hex: %h", toByteFromAscii);
        end
    endfunction

    function [15:0] getByteFromAsciiStr;
        input [8*2*512:0] cmd; // 8 bits/char * 2chars/byte * 260 bytes
        input [32:0] msb;
        reg [15:0] work;
        begin

        work[15] = cmd[msb];    //must be a better way to do this
        work[14] = cmd[msb-1];
        work[13] = cmd[msb-2];
        work[12] = cmd[msb-3];
        work[11] = cmd[msb-4];
        work[10] = cmd[msb-5];
        work[9]  = cmd[msb-6];
        work[8]  = cmd[msb-7];
        work[7]  = cmd[msb-8];
        work[6]  = cmd[msb-9];
        work[5]  = cmd[msb-10];
        work[4]  = cmd[msb-11];
        work[3]  = cmd[msb-12];
        work[2]  = cmd[msb-13];
        work[1]  = cmd[msb-14];
        work[0]  = cmd[msb-15];
        
        //$display("Work: %h", work);
        getByteFromAsciiStr = toByteFromAscii(work);
        end
    endfunction

        
    //
    // parse a hex-as-string command into a binary command
    // and transmit it to the ice simulation
    //
    task send_command_0;
        input [8*2*260:0] cmd; // 8 bits/char * 2chars/byte * 260 bytes
        input [32:0]    cmd_size; // only 8 needed?
        integer i;
        reg [32:0] msb;
        reg [7:0] theByte;

        //transmit our message, one byte at a time
        for (i = cmd_size-1 ; i >= 0; i = i - 1) begin
            msb= (1+i)*16  - 1;
            theByte = getByteFromAsciiStr(cmd, msb);

            $display ("TX0: %h", theByte);
             uart_0_tx_data <= theByte;
             uart_0_tx_latch <= 1;
            @(posedge clk);
             uart_0_tx_latch <= 1'b0;
            @(posedge clk);
            @(posedge uart_0_tx_empty);
            
        end
    endtask  

    //
    //
    //
    task wait_for_rx_0;
        input [32:0]    rxBytes;
        integer i;
    begin
        i = 0;
        //wait for an ack/nak
        while (i < rxBytes ) begin 
            if (uart_0_rx_latch) begin
                $display("\tRX0: %h", uart_0_rx_data);
                i = i + 1;
                while( uart_0_rx_latch) @(posedge clk);
            end else begin
                @(posedge clk);
            end
        end
    end
    endtask 


    //
    // parse a hex-as-string command into a binary command
    // and transmit it to the ice simulation
    //
    task send_command_1;
        input [8*2*260:0] cmd; // 8 bits/char * 2chars/byte * 260 bytes
        input [32:0]    cmd_size; // only 8 needed?

        integer i;
        reg [32:0] msb;
        reg [7:0] theByte;

        //transmit our message, one byte at a time
        for (i = cmd_size-1 ; i >= 0; i = i - 1) begin
            msb= (1+i)*16  - 1;
            theByte = getByteFromAsciiStr(cmd, msb);

            $display ("\t\tTX1: %h", theByte);
             uart_1_tx_data <= theByte;
             uart_1_tx_latch <= 1;
            @(posedge clk);
             uart_1_tx_latch <= 1'b0;
            @(posedge clk);
            @(posedge uart_1_tx_empty);
            
        end
    endtask  

    //
    //
    //
    task wait_for_rx_1;
        input [32:0]    rxBytes;
        integer i;
    begin
        i = 0;
        //wait for an ack/nak
        while (i < rxBytes ) begin 
            if (uart_1_rx_latch) begin
                $display("\t\t\tRX1: %h", uart_1_rx_data);
                i = i + 1;
                while( uart_1_rx_latch) @(posedge clk);
            end else begin
                @(posedge clk);
            end
        end
    end
    endtask 

    //
    //
    //
`ifndef SIM_FLAG
    task assert;
        input condition;
        if(!condition) begin
            $display("@@@FAILED: assertion");
            $finish(2);
        end
    endtask
`endif    

initial
begin
    integer i,j,k;

    //Initialize the clock...
	clk = 0;
	reset = 1;
    ice_0_dout_count = 0;
    ice_1_uart_rxd_count = 0;

	// top-level resets
	uart_0_tx_latch = 1'b0;
	uart_1_tx_latch = 1'b0;

    //#(SYSCLK_PERIOD * 10 )
    //    reset = 0;

	//Wait for the reset circuitry to kick in...
    for (i = 0; i < 10; i = i + 1) @(negedge clk)        
	@ (posedge clk);
	 reset = 0;
	@ (posedge clk);

    //mbus_reset_on
	//mbus_set_master_on
	//mbus_set_short_prefix_to_1
	//mbus_reset_off
    send_command_1("6d0f027201", 32'd5);
    wait_for_rx_1(32'd3);
	send_command_1("6d0d026d01", 32'd5);
    wait_for_rx_1(32'd3);
	send_command_1("6d10027301", 32'd5);
    wait_for_rx_1(32'd3);
	send_command_1("6d0f027200", 32'd5);
    wait_for_rx_1(32'd3);

     //now go back to ice0
    assert( ice_0_dout_count < 2) else $fatal(1); // 0 or 1
    ice_0_dout_count = 0;
    ice_1_uart_rxd_count = 0;
  
    //v0.4 speed probe
    //skip the slow one?
    send_command_0("560000",32'd3);
    wait_for_rx_0(32'd5);

	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //m3_ice startup version probe 
    send_command_0("560000",32'd3);
    wait_for_rx_0(32'd5);
    //assert( ice_0_dout_count == 23) else $fatal(1);
	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //?
    send_command_0("7601020004",32'd5);
    wait_for_rx_0(32'd3);
	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //?
    send_command_0("3f02013f",32'd4);
    wait_for_rx_0(32'd14);
	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //?
    send_command_0("6f0305630061a800",32'd8);
    wait_for_rx_0(32'd3);
	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //?
    send_command_0("6f04027001",32'd5);
    wait_for_rx_0(32'd3);
	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //?
    send_command_0("6f05026f00",32'd5);
    wait_for_rx_0(32'd3);
	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //
    // PMU stuff doesn't appear to work correctly here?
    //

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("7006036f0301",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);
   
    //extra delay in real life...
	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700703760013",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700803760119",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700903760219",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700a036f0201",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700b036f0101",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700c036f0001",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700c036f0001",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700d036f0000",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    // this one doesn't seem to get ACK'ed?
    ////?
    //send_command_0("700e036f0001",32'd6);
    ////wait_for_rx_0(32'd3);
	//for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //?
    send_command_0("6d0f026d00",32'd5);
    wait_for_rx_0(32'd3);
	for(i = 0; i < 1000; i=i+1) @(posedge clk);


	for(i = 0; i < 1000; i=i+1) @(posedge clk);

    //MBUS Tx
    send_command_0("620c08f0123450deadbeef", 32'd11);
    wait_for_rx_0(32'd3);
    assert( ice_0_dout_count == 22) else $fatal(1); //30?
    ice_0_dout_count = 0;

    //MBUS Mem Wr - raise CPU reset
    send_command_0("62080c00000012affff000cafef00d", 32'd15);
    wait_for_rx_0(32'd3);
    assert( ice_0_dout_count == 19) else $fatal(1);
    ice_0_dout_count = 0;
    //check the ICE Rx on that
	for(i = 0; i < 5000; i=i+1) @(posedge clk);
    assert( ice_1_uart_rxd_count  == 29) else $fatal(1);
    ice_1_uart_rxd_count = 0;


    //
    //BIG MBUS bulk memory write
    //
    send_command_0(
        "621418000000120000000000200000910000000000000000000000",
        32'd27); 
    wait_for_rx_0(16'd3);
    assert( ice_0_dout_count == 14) else $fatal(1);
    ice_0_dout_count = 0;
    //check the ICE Rx on that
	for(i = 0; i < 5000; i=i+1) @(posedge clk);
    assert( ice_1_uart_rxd_count  == 39) else $fatal(1);
    ice_1_uart_rxd_count = 0;



    send_command_0(
        "62100c000000120000002080000000", 
        32'd15);
    wait_for_rx_0(16'd3);
    assert( ice_0_dout_count == 12) else $fatal(1);
    ice_0_dout_count = 0;
    //check the ICE Rx on that
	for(i = 0; i < 5000; i=i+1) @(posedge clk);
    assert( ice_1_uart_rxd_count  == 25 ) else $fatal(1);
    ice_1_uart_rxd_count = 0;

    //$display( "ice_0_dout_count:%d", ice_0_dout_count);
    //$display( "ice_1_uart_rxd_count:%d", ice_1_uart_rxd_count );

	for(i = 0; i < 100000; i=i+1) @(posedge clk);

    $display("@@@Passed");
	$finish;

end




endmodule

