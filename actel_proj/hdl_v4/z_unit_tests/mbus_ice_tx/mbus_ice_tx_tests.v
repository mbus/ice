
`timescale 1ns/1ps

`define SD #125

module testbench;

    //
    // CLOCK + RESET
    //
    reg         clock;
    reg         reset;


    //
    // MBUS ICE DRIVER SIGNALS
    //

	reg [19:0]  mbus_long_addr;
	reg [3:0]   mbus_short_addr_override;
	reg         MASTER_NODE;
	reg         mbus_snoop_enabled;
	reg [21:0]  mbus_clk_div;
	reg         mbus_tx_prio;

	reg 	    CLKIN; 
	wire        CLKOUT;
	reg 	    DIN; 
	wire 	    DOUT; 

	//Master input bus
	reg [7:0]   ma_data;
	reg [7:0]   ma_addr;
	reg         ma_data_valid;
	reg         ma_frame_valid;
	wire        sl_overflow;
	
	//Slave output bus
	reg [8:0]   sl_addr;
	wire[8:0]   sl_tail;
	reg         sl_latch_tail;
	wire [8:0]  sl_data;
	wire [1:0]  sl_arb_request;
	reg [1:0]   sl_arb_grant;
	
	//Global counter for 'time-tagging'
	reg [7:0]   global_counter;
	wire        incr_ctr;
	
	wire [3:0]  debug;

    // 
    // SIGNALS FOR TESTING
    //
    integer i;
    integer DOUT_low_count;
    reg [7:0] test_message [254:0];


    // clock 
    always #1250 clock = ~clock;

    //connect the TXMbus and RXMbus
    assign #10000 CLKIN = CLKOUT;
    assign #10000 DIN = DOUT;


    //
    // Actual Mbus ice module
    //
    mbus_layer_wrapper_ice mbus_ice0 (
        .clk( clock ),
        .reset( reset ),

        .mbus_long_addr( mbus_long_addr ),
        .mbus_short_addr_override( mbus_short_addr_override ),
        .MASTER_NODE( MASTER_NODE ),
        .mbus_snoop_enabled( mbus_snoop_enabled ),
        .mbus_clk_div( mbus_clk_div ),
        .mbus_tx_prio( mbus_tx_prio ),

        .CLKIN( CLKIN ), 
        .CLKOUT( CLKOUT ),
        .DIN( DIN ), 
        .DOUT( DOUT ), 

        //Master input bus
        .ma_data( ma_data ),
        .ma_addr( ma_addr ),
        .ma_data_valid( ma_data_valid ),
        .ma_frame_valid( ma_frame_valid ),
        .sl_overflow( sl_overflow ),

        //Slave output bus
        .sl_addr( sl_addr ),
        .sl_tail( sl_tail ),
        .sl_latch_tail( sl_latch_tail ),
        .sl_data( sl_data ),
        .sl_arb_request( sl_arb_request ),
        .sl_arb_grant( sl_arb_grant ),

        //Global counter for 'time-tagging'
        .global_counter( global_counter ),
        .incr_ctr( incr_ctr ),

        .debug( debug )
    );

  
    //always @(posedge clock)
    //begin
    //    if (!correct_rx_latch)
    //    begin
    //        $display("rx_data=%h, expected=%h", rx_data , expect_rx_data);
    //        $display("rx_latch=%h, expected=%h", rx_latch , expect_rx_latch);
    //        $display("@@@FAILED");
    //        $finish;
    //    end
    //end
    always @(negedge DOUT) begin
        DOUT_low_count = DOUT_low_count + 1;
    end

    //
    //
    //
    task send_message;
        input reg [7:0]     data_arr [254:0];
        input reg [15:0]    data_len;
        integer idx;
        assert(data_len > 0)  else $fatal(1);
        
        // pick a slow starting point
        @(negedge mbus_ice0.mbus_clk);

        //start frame + hardcode first byte
        ma_frame_valid = 1;
        $display("Send: %h", data_arr[0]);
        ma_addr = data_arr[0];

        // transmit remaining bytes 
        for(idx =1; idx < data_len; idx = idx + 1) begin
            send_byte(data_arr[idx]);
            $display("Send: %h", data_arr[idx]);
        end

        //end of frame
        @(negedge clock); 
        ma_frame_valid = 0;


        //wait for an ACK/NAK
        while (sl_arb_request != 2'h2) @(negedge clock);
        
        //let the ACK/NAK flow out
        @(negedge clock); 
        sl_arb_grant = 2'h2;
        @(negedge clock); 
        //wait until we get a done signal
        while ( sl_data[8] != 1 ) begin 
            @(negedge clock); 
            @(negedge clock); 
            $display("Resp: %h", sl_data[7:0]);
            sl_addr <= sl_addr + 1;
        end

        sl_latch_tail = 1;
        @(negedge clock);
        sl_latch_tail = 0;
        sl_arb_grant = 2'h0;

    endtask
      
    //
    //
    //
    task send_byte;
        input reg [7:0] data;
        
        //slow
        @(negedge mbus_ice0.mbus_clk);
        @(negedge clock);
        ma_data_valid = 1;
        ma_data = data;
        //now back to fast 
        @(negedge clock);
        ma_data_valid = 0;

    endtask

    initial
    begin
        //$monitor("CLKOUT:%h, DOUT:%h", TXM_clkout, RXM_dout);
        DOUT_low_count = 0; 

        // Shared signals
        clock = 0;
        reset = 1;

        mbus_long_addr = 20'hA;
        mbus_short_addr_override = 0;
        MASTER_NODE = 1;
        mbus_snoop_enabled = 0;
        mbus_clk_div = 22'h20;
        mbus_tx_prio = 0;

        //Master input bus
        ma_data = 8'h0;
        ma_addr = 8'h0;
        ma_data_valid = 0;
        ma_frame_valid = 0;
        
        //Slave output bus
        sl_addr = 8'h0;
        sl_latch_tail = 0;
        sl_arb_grant = 2'h0;
        
        //Global counter for 'time-tagging'
        global_counter = 8'h0;
        
        for (i = 0; i < 255; i = i + 1) begin
            test_message[i] = 8'h0;
        end

        @(negedge clock); 
        @(negedge clock); 
        reset = 0;

        //to run slower we'll run everyting at mbus frequency
        @(negedge mbus_ice0.mbus_clk);
        @(negedge mbus_ice0.mbus_clk);

        
        $display("\nSending First Message\n");
        test_message[0] = 8'h62;
        test_message[1] = 8'h0a;
        test_message[2] = 8'h08;
        test_message[3] = 8'hf0;
        test_message[4] = 8'h12;
        test_message[5] = 8'h34;
        test_message[6] = 8'h50;
        test_message[7] = 8'hde;
        test_message[8] = 8'had;
        test_message[9] = 8'hbe;
        test_message[10] = 8'hef;

        send_message(test_message,11);

        // cheap quick way of making sure we actually transmitted something
        // reasonally correct
        assert( DOUT_low_count == 23) else $fatal(1);
        @(negedge clock);

        for (i = 0; i < 10000; i = i + 1) begin
            @(negedge clock);
        end

        DOUT_low_count = 0;
        global_counter = 8'h1;

        $display("\nSending Second Message\n");
        test_message[0] = 8'h62;
        test_message[1] = 8'h0b;
        test_message[2] = 8'h0c;
        test_message[3] = 8'hf0;
        test_message[4] = 8'h00;
        test_message[5] = 8'h00;
        test_message[6] = 8'ha2;

        test_message[7] = 8'had;
        test_message[8] = 8'hd3;
        test_message[9] = 8'hde;
        test_message[10] = 8'had;

        test_message[11] = 8'hba;
        test_message[12] = 8'had;
        test_message[13] = 8'hbe;
        test_message[14] = 8'hef;

        send_message(test_message,15);

        //longer message, more wiggles
        assert( DOUT_low_count == 31) else $fatal(1);
        
        for (i = 0; i < 1000; i = i + 1) begin
            @(negedge clock);
        end

        @(negedge clock);
        DOUT_low_count = 0;
        global_counter = 8'h2;

        $display("\nSending Third Message\n");
        test_message[0] = 8'h62;
        test_message[1] = 8'h0b;
        test_message[2] = 8'h0c;
        test_message[3] = 8'hf0;
        test_message[4] = 8'h00;
        test_message[5] = 8'h00;
        test_message[6] = 8'ha2;

        test_message[7] = 8'had;
        test_message[8] = 8'hdd;
        test_message[9] = 8'had;
        test_message[10] = 8'hdd;

        test_message[11] = 8'h12;
        test_message[12] = 8'h13;
        test_message[13] = 8'h14;
        test_message[14] = 8'h15;

        test_message[15] = 8'h23;
        test_message[16] = 8'h24;
        test_message[17] = 8'h25;
        test_message[18] = 8'h26;


        send_message(test_message,19);

        //longer message, more wiggles
        assert( DOUT_low_count == 40) else $fatal(1);
        

        for (i = 0; i < 10000; i = i + 1) begin
            @(negedge clock);
        end

        $display("@@@Passed");
        $finish;
    end
endmodule

