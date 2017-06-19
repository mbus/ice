`timescale 1ns/1ps

`include "include/ice_def.v"

`define MEM_SIZE 200_000
`define SIM_FLAG

module tb_ice();

    reg [8*255:0]   cmd;
    reg [15:0]      cmd_size;

integer file, n, i, j, k;

integer mem_idx_0, mem_idx_1;
reg [7:0] mem_0[0:`MEM_SIZE];
reg [7:0] mem_1[0:`MEM_SIZE];

reg clk;
reg reset;


wire ice_0_dout, ice_0_cout, ice_1_dout, ice_1_cout;
wire ice_0_din,  ice_0_cin,  ice_1_din,  ice_1_cin;

// http://www-inst.eecs.berkeley.edu/~cs152/fa06/handouts/CummingsHDLCON1999_BehavioralDelays_Rev1_1.pdf
// Use LHS for delays in continuous assignment
assign #10000 ice_0_din = ice_1_dout;
assign #10000 ice_0_cin = ice_1_cout;
assign #10000 ice_1_din = ice_0_dout;
assign #10000 ice_1_cin = ice_0_cout;

wire        uart_0_rxd;
wire        uart_0_txd;

wire        uart_0_rx_latch;
wire [7:0]  uart_0_rx_data;

reg         uart_0_tx_latch;
reg [7:0]   uart_0_tx_data;
wire        uart_0_tx_empty;

//
// Generate UART signals for input into m3_ice_top
//
uart u0(
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

m3_ice_top t0(
	.SYS_CLK(clk),
	.PB({3'b111,~reset}),

	.USB_UART_RXD(uart_0_rxd),
	.USB_UART_TXD(uart_0_txd),

	.FPGA_MB_DOUT(ice_0_dout),
	.FPGA_MB_COUT(ice_0_cout),
	.FPGA_MB_DIN(ice_0_din),
	.FPGA_MB_CIN(ice_0_cin)
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
	.baud_div(16'd10),
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

	.FPGA_MB_DOUT(ice_1_dout),
	.FPGA_MB_COUT(ice_1_cout),
	.FPGA_MB_DIN(ice_1_din),
	.FPGA_MB_CIN(ice_1_cin)
);




    //
    // Stuff for parsing the string command into binary
    //
    function [3:0] asciiToNum;
        input [7:0] ascii;
        // < '0'
        if (ascii < 8'h30) $fatal(1);
        // '0' - '9'
        else if ( ascii < 8'h3A) asciiToNum = ascii - 8'h30; // '0'
        else if (ascii < 8'h41) $fatal(1);
        else if (ascii < 8'h47) asciiToNum = ascii - 8'h41 + 8'd10; //'A'=10
        else if (ascii < 8'h61) $fatal(1);
        else if (ascii < 8'h67) asciiToNum = ascii - 8'h61 + 8'd10; //'a'=10
        else $fatal(1);
    endfunction 

    function [7:0] toByteFromAscii;
        input [15:0] hex_string;
        toByteFromAscii[7:4] = asciiToNum(hex_string[15:8]);
        toByteFromAscii[3:0] = asciiToNum(hex_string[7:0]);
        //$display("%h", toByte);
    endfunction

    function [15:0] getByteFromAsciiStr;
        input [8*255:0] cmd; // 1 extra bit?
        input [15:0] msb;
        reg [15:0] work;

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

        getByteFromAsciiStr = toByteFromAscii(work);
    endfunction

        
    //
    // parse a hex-as-string command into a binary command
    // and transmit it to the ice simulation
    //
    task send_command_0;
        input [8*255:0] cmd; // 1 extra bit?
        input [15:0]    cmd_size; // only 8 needed?

        integer i;
        reg [15:0] msb;
        reg [7:0] theByte;

        //transmit our message, one byte at a time
        for (i = cmd_size-1 ; i >= 0; i = i - 1) begin
            msb= (1+i)*16  - 1;
            theByte = getByteFromAsciiStr(cmd, msb);

            $display ("TX0: %h", theByte);
            `SD uart_0_tx_data <= theByte;
            `SD uart_0_tx_latch <= 1;
            @(posedge clk);
            `SD uart_0_tx_latch <= 1'b0;
            @(posedge clk);
            @(posedge uart_0_tx_empty);
            
        end
    endtask  

    //
    //
    //
    task wait_for_rx_0;
        input [15:0]    rxBytes;
        integer i;
        i = 0;
        //wait for an ack/nak
        while (i < rxBytes ) begin 
            if (uart_0_rx_latch) begin
                $display("\tRX0: %h", uart_0_rx_data);
                i = i + 1;
                @(negedge uart_0_rx_latch);
            end else begin
                @(posedge clk);
            end
        end
    endtask 




//task send_command_0;
//	input reg [80*8:1] file_name;
//	integer resp_hack;
//	begin
//
//	$display("Start %s", file_name);
//
//	file = $fopen(file_name,"r");
//	@ (posedge clk);
//	n = $fread(mem_0, file);
//	@(posedge clk);
//	for(mem_idx_0 = 0; mem_idx_0 < n; mem_idx_0=mem_idx_0+1) begin
//		`SD uart_0_tx_latch = 1'b1;
//		@(posedge clk);
//		`SD uart_0_tx_latch = 1'b0;
//		@(posedge clk);
//		@(posedge uart_0_empty);
//	end
//	$fclose(file);
//
//	while (1'b1) begin
//		resp_hack = 0;
//		for (k=0; k<2000; k=k+1) begin
//			if (uart_0_rx_latch) begin
//				resp_hack = 1;
//			end
//			@(posedge clk);
//		end
//
//		if (resp_hack == 0) begin
//			break;
//		end
//	end
//
//	$display("End   %s", file_name);
//	end
//endtask

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

    //make ice1 the master
	send_command_1("../../../test_sequences/mbus_reset_on");
	send_command_1("../../../test_sequences/mbus_set_master_on");
	send_command_1("../../../test_sequences/mbus_reset_off");

    //now go back to ice0
   
    //MBUS internal reset on
    send_command_0( "6d0a027201", 16'd5);
    wait_for_rx_0(16'd3);

    //MBUS internal reset off
    send_command_0( "6d0b027200", 16'd5);
    wait_for_rx_0(16'd3);

    //MBUS Tx
    send_command_0("620c08f0123450deadbeef", 16'd11);
    wait_for_rx_0(16'd3);

    //Wait for stuff to happen...
	for(i = 0; i < 10000; i=i+1) begin
		@(posedge clk);
	end

    $display("@@@Passed");
	$finish;
end

always #1250 clk = ~clk;

endmodule // testbench
