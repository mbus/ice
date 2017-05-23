
`timescale 1ns/1ps

`define SD #125

module testbench;

    //
    // CLOCK + RESET
    //
    reg         clock;
    reg         reset;
    wire        resetN;

    always #12500 clock = ~clock;
    assign resetN = ~reset;

    // 
    //  MBUS_CLK is slower than clock
    //
    reg         mbus_clk_div;
    reg [5:0]   mbus_clk_cntr;
    reg         mbus_clk;

    always @(posedge clock) begin
        if (~resetN) begin

            mbus_clk <= 0;
            mbus_clk_cntr <= 6'h0;
        end else begin

            if (mbus_clk_cntr == mbus_clk_div) begin
                mbus_clk_cntr <= 6'h0;
                mbus_clk <= ~mbus_clk;

            end else begin
                mbus_clk_cntr <= mbus_clk_cntr + 6'h1;
            end
        end // else  begin
    end //always
 

    //
    // SIGNALS shared for TXMbus and RXMbus
    //
    reg         master_en; // TXM always master RXM always slave
    reg         mbus_snoop_enabled;

    //
    // SIGNALS for the TXMbus
    //
    reg [19:0]  TXM_address;
    reg [3:0]   TXM_assigned_addr_in;
    reg         TXM_assigned_addr_valid;

    reg         TXM_clkin;
    reg         TXM_din;

    reg [31:0]  TXM_tx_addr;
    reg [31:0]  TXM_tx_data;
    reg         TXM_tx_pend;
    reg         TXM_tx_req;
    reg         TXM_tx_priority;
    reg         TXM_tx_resp_ack;
    
    reg         TXM_rx_ack;
    
    wire [3:0]  TXM_assigned_addr_out;
    wire        TXM_assigned_addr_write;
    wire        TXM_assigned_addr_invalidN;

    wire        TXM_clkout;
    wire        TXM_dout;

    wire        TXM_tx_ack;
    wire        TXM_tx_fail;
    wire        TXM_tx_succ;

    wire [31:0] TXM_rx_addr;
    wire [31:0] TXM_rx_data;
    wire        TXM_rx_req;
    wire        TXM_rx_broadcast;
    wire        TXM_rx_fail;
    wire        TXM_rx_pend;

    wire [1:0]  TXM_ice_export_control_bits;

    // 
    // SIGNALS for the RXMbus
    // 
    reg [19:0]  RXM_address;
    reg [3:0]   RXM_assigned_addr_in;
    reg         RXM_assigned_addr_valid;

    reg         RXM_clkin;
    reg         RXM_din;

    reg [31:0]  RXM_tx_addr;
    reg [31:0]  RXM_tx_data;
    reg         RXM_tx_pend;
    reg         RXM_tx_req;
    reg         RXM_tx_priority;
    reg         RXM_tx_resp_ack;
    
    reg         RXM_rx_ack;
    
    wire [3:0]  RXM_assigned_addr_out;
    wire        RXM_assigned_addr_write;
    wire        RXM_assigned_addr_invalidN;

    wire        RXM_clkout;
    wire        RXM_dout;

    wire        RXM_tx_ack;
    wire        RXM_tx_fail;
    wire        RXM_tx_succ;

    wire [31:0] RXM_rx_addr;
    wire [31:0] RXM_rx_data;
    wire        RXM_rx_req;
    wire        RXM_rx_broadcast;
    wire        RXM_rx_fail;
    wire        RXM_rx_pend;

    wire [1:0]  RXM_ice_export_control_bits;


    //
    // TX MBUS
    //
    mbus_general_layer_wrapper TXMbus(
        .CLK_EXT(mbus_clk),
        .MASTER_EN(master_en),
        .mbus_snoop_enabled(mbus_snoop_enabled),
        .ADDRESS(TXM_address),
        .ASSIGNED_ADDR_IN(TXM_assigned_addr_in),
        .ASSIGNED_ADDR_OUT(TXM_assigned_addr_out),
        .ASSIGNED_ADDR_VALID(TXM_assigned_addr_valid),
        .ASSIGNED_ADDR_WRITE(TXM_assigned_addr_write),
        .ASSIGNED_ADDR_INVALIDn(TXM_assigned_addr_invalidN),
        .CLKIN(TXM_clkin),
        .CLKOUT(TXM_clkout),
        .RESETn(resetN),
        .DIN(TXM_din),
        .DOUT(TXM_dout),
        .TX_ADDR(TXM_tx_addr),
        .TX_DATA(TXM_tx_data), 
        .TX_PEND(TXM_tx_pend), 
        .TX_REQ(TXM_tx_req), 
        .TX_PRIORITY(TXM_tx_priority),
        .TX_ACK(TXM_tx_ack), 
        .RX_ADDR(TXM_rx_addr), 
        .RX_DATA(TXM_rx_data), 
        .RX_REQ(TXM_rx_req), 
        .RX_ACK(TXM_rx_ack), 
        .RX_BROADCAST(TXM_rx_broadcast),
        .RX_FAIL(TXM_rx_fail),
        .RX_PEND(TXM_rx_pend), 
        .ice_export_control_bits(TXM_ice_export_control_bits),
        .TX_FAIL(TXM_tx_fail), 
        .TX_SUCC(TXM_tx_succ), 
        .TX_RESP_ACK(TXM_tx_resp_ack)

    );

    //
    // RX MBUS
    //
    mbus_general_layer_wrapper RXMbus(
        .CLK_EXT(mbus_clk),
        .MASTER_EN(~master_en), //RX never master
        .mbus_snoop_enabled(mbus_snoop_enabled),
        .ADDRESS(RXM_address),
        .ASSIGNED_ADDR_IN(RXM_assigned_addr_in),
        .ASSIGNED_ADDR_OUT(RXM_assigned_addr_out),
        .ASSIGNED_ADDR_VALID(RXM_assigned_addr_valid),
        .ASSIGNED_ADDR_WRITE(RXM_assigned_addr_write),
        .ASSIGNED_ADDR_INVALIDn(RXM_assigned_addr_invalidN),
        .CLKIN(RXM_clkin),
        .CLKOUT(RXM_clkout),
        .RESETn(resetN),
        .DIN(RXM_din),
        .DOUT(RXM_dout),
        .TX_ADDR(RXM_tx_addr),
        .TX_DATA(RXM_tx_data), 
        .TX_PEND(RXM_tx_pend), 
        .TX_REQ(RXM_tx_req), 
        .TX_PRIORITY(RXM_tx_priority),
        .TX_ACK(RXM_tx_ack), 
        .RX_ADDR(RXM_rx_addr), 
        .RX_DATA(RXM_rx_data), 
        .RX_REQ(RXM_rx_req), 
        .RX_ACK(RXM_rx_ack), 
        .RX_BROADCAST(RXM_rx_broadcast),
        .RX_FAIL(RXM_rx_fail),
        .RX_PEND(RXM_rx_pend), 
        .ice_export_control_bits(RXM_ice_export_control_bits),
        .TX_FAIL(RXM_tx_fail), 
        .TX_SUCC(RXM_tx_succ), 
        .TX_RESP_ACK(RXM_tx_resp_ack)

    );



    // 
    // SIGNALS FOR TESTING
    //
    integer i;

    //connect the TXMbus and RXMbus
    assign #10000 TXM_clkin = RXM_clkout;
    assign #10000 RXM_clkin = TXM_clkout;
    assign #10000 TXM_din = RXM_dout;
    assign #10000 RXM_din = TXM_dout;

   
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


    initial
    begin
        //$monitor("CLKOUT:%h, DOUT:%h", TXM_clkout, RXM_dout);

        // Shared signals
        clock = 0;
        mbus_clk_div = 6'h20;
        reset = 1;
        master_en = 1;
        mbus_snoop_enabled = 0;

        //TXM-bus
        TXM_address = 20'h0A;
        TXM_assigned_addr_in = 4'hA;
        TXM_assigned_addr_valid = 0;

        TXM_tx_addr = 32'hf00000B0; // f=Long Address, 0..0B=MBUS address 0xB, 0= MBUS Reg Write
        TXM_tx_data = 32'h0A00feed; //0A: mbus register, 00feed: register data
        TXM_tx_pend = 0;
        TXM_tx_req = 0;
        TXM_tx_priority = 0;
        TXM_tx_resp_ack = 0;
        TXM_rx_ack= 0;

        //RXM-bus
        RXM_address = 20'h0B;
        RXM_assigned_addr_in = 4'hB;
        RXM_assigned_addr_valid = 0;

        RXM_tx_addr = 32'h0;
        RXM_tx_data = 32'h0;
        RXM_tx_pend = 0;
        RXM_tx_req = 0;
        RXM_tx_priority = 0;
        RXM_tx_resp_ack = 0;
        RXM_rx_ack= 0;

        @(negedge clock); 

        @(negedge clock); 
        reset = 0;

        @(negedge clock); 
        $display("TXM:\nTXM: fist packet (should ACK)\nTXM:");
        $display("TXM: asserting TX_REQ");
        assert( TXM_tx_ack == 0) else $fatal(1);
        TXM_tx_req = 1;
        
        while( TXM_tx_ack == 0) @(negedge clock); 
        $display("TXM:Got TX_ACK, Deasserting TX_REQ");
        TXM_tx_req = 0;

        // should get ACKed
        while ( (TXM_tx_fail == 0) && (TXM_tx_succ == 0) ) @(negedge clock); 
        assert( TXM_tx_succ == 1) else $fatal(1);
        assert( TXM_tx_fail == 0) else $fatal(1);
        $display("TXM:Got TX_SUCC, Sending TX_RESP_ACK"); 
        TXM_tx_resp_ack = 1;

        @(negedge clock);
        $display("TXM: Done TX_RESP_ACK"); 
        TXM_tx_resp_ack = 0;

        assert( RXM_rx_req == 1); 
        assert( RXM_rx_addr == 32'hf00000b0 );
        assert( RXM_rx_data == 32'h0a00feed);
        $display("RXM: RX_REQ high, correct addr/data, assert RX_ACK");

        RXM_rx_ack = 1;

        @(negedge clock);
        assert( RXM_rx_req == 0);
        $display("RXM: RX_REQ low, deasserting RX_ACK");
        RXM_rx_ack = 0;


        for (i = 0; i < 1000; i = i + 1) begin
            @(negedge clock);
        end

        @(negedge clock);
        $display("TXM:\nTXM: Sending second packet (should NAK)\nTXM");
        $display("TXM: asserting TX_REQ and TX_PEND");
        TXM_tx_req = 1;
        TXM_tx_pend = 1;
        TXM_tx_addr = 32'hf00000C0; //Not the RXM address
        TXM_tx_data = 32'hfeedface;

        $display("TXM: Waiting for TX_ACK to go high");
        while(TXM_tx_ack == 0) @(negedge clock); 

        $display("TXM: TX_ACK is high, TX_REQ goes low, TX_PEND stays high");
        TXM_tx_req = 0;
        TXM_tx_pend = 1; // keep this high

        $display("TXM: Waiting for TX_ACK to go low");
        while (TXM_tx_ack == 1) @(negedge clock);
        
        $display("TX_ACK is low, setup for next word");
        TXM_tx_req = 1;
        TXM_tx_pend = 1; // keep this high
        TXM_tx_data = 32'hF0F0F0F0;

        $display("Waiting for TX_ACK to go high");
        while(TXM_tx_ack == 0) @(negedge clock); 

        $display("TX_ACK is high, TX_REQ goes low, TX_PEND stays high");
        TXM_tx_req = 0;
        TXM_tx_pend = 1; // keep this high

        $display("Waiting for TX_ACK to go low");
        while (TXM_tx_ack == 1) @(negedge clock);

        $display("TX_ACK low, setup for last word");
        TXM_tx_req = 1;
        TXM_tx_pend = 0; //last word, now this goes low
        TXM_tx_data = 32'h0000000F;

        $display("Waiting for TX_ACK to go high");
        while(TXM_tx_ack == 0) @(negedge clock); 

        $display("Got final TX_ACK, deasserting TX_REQ");
        TXM_tx_req = 0;
        
        $display("waiting for tx_fail or tx_succ");
        while ( (TXM_tx_fail == 0) && (TXM_tx_succ == 0) ) @(negedge clock); 
        assert( TXM_tx_succ == 0) else $fatal(1);
        assert( TXM_tx_fail == 1) else $fatal(1);

        $display("SEND TX_RESP_ACK");
        TXM_tx_resp_ack = 1;

        @(negedge clock);
        TXM_tx_resp_ack = 0;
        
        for (i = 0; i < 1000; i = i + 1) begin
            @(negedge clock);
        end

        @(negedge clock);
        $display("TXM:\nTXM: Sending third packet (should ACK)\nTXM");
        $display("TXM: asserting TX_REQ and TX_PEND");
        TXM_tx_req = 1;
        TXM_tx_pend = 1;
        TXM_tx_addr = 32'hf00000B0; //Yes the RXM address
        TXM_tx_data = 32'hdeadbeef;

        $display("TXM: Waiting for 1st TX_ACK to go high");
        while(TXM_tx_ack == 0) @(negedge clock); 

        $display("TXM: TX_ACK is high, TX_REQ goes low, TX_PEND stays high");
        TXM_tx_req = 0;
        TXM_tx_pend = 1; // keep this high

        $display("TXM: Waiting for 1st TX_ACK to go low");
        while (TXM_tx_ack == 1) @(negedge clock);
        
        $display("TXM: TX_ACK is low, setup for next word");
        TXM_tx_req = 1;
        TXM_tx_pend = 1; // keep this high
        TXM_tx_data = 32'hF0F0F0F0;

        $display("TXM: Waiting for 2nd TX_ACK to go high");
        while(TXM_tx_ack == 0) @(negedge clock); 

        $display("TXM: TX_ACK is high, TX_REQ goes low, TX_PEND stays high");
        TXM_tx_req = 0;
        TXM_tx_pend = 1; // keep this high

        $display("RXM: Waiting for TX_ACK to go low");
        while (RXM_rx_req == 0) @(negedge clock);
        assert( RXM_rx_req == 1); 
        assert( RXM_rx_pend == 1); 
        assert( RXM_rx_addr == 32'hf00000b0 );
        assert( RXM_rx_data == 32'hdeadbeef);
        $display("RXM: RX_REQ high, correct addr/data, assert RX_ACK");
        RXM_rx_ack = 1;

        @(negedge clock);
        assert( RXM_rx_req == 0);
        $display("RXM: RX_REQ low, deasserting RX_ACK");
        RXM_rx_ack = 0;

        $display("TXM: Waiting for TX_ACK to go low");
        while (TXM_tx_ack == 1) @(negedge clock);

        $display("TXM: TX_ACK low, setup for last word");
        TXM_tx_req = 1;
        TXM_tx_pend = 0; //last word, now this goes low
        TXM_tx_data = 32'h0000000F;

        $display("TXM: Waiting for TX_ACK to go high");
        while(TXM_tx_ack == 0) @(negedge clock); 

        $display("TXM: Got final TX_ACK, deasserting TX_REQ");
        TXM_tx_req = 0;

        $display("RXM: Waiting for RX_REQ to go low");
        while (RXM_rx_req == 0) @(negedge clock);

        assert( RXM_rx_req == 1); 
        assert( RXM_rx_pend == 1); 
        assert( RXM_rx_data == 32'hf0f0f0f0);
        $display("RXM: RX_REQ high, correct addr/data, assert RX_ACK");
        RXM_rx_ack = 1;

        @(negedge clock);
        assert( RXM_rx_req == 0);
        $display("RXM: RX_REQ low, deasserting RX_ACK");
        RXM_rx_ack = 0;

        $display("RXM: Waiting for RX_REQ to go low");
        while (RXM_rx_req == 0) @(negedge clock);

        assert( RXM_rx_req == 1); 
        assert( RXM_rx_pend == 0); 
        assert( RXM_rx_data == 32'h0000000f);
        $display("RXM: RX_REQ high, correct addr/data, assert RX_ACK");
        RXM_rx_ack = 1;

        @(negedge clock);
        assert( RXM_rx_req == 0);
        $display("RXM: RX_REQ low, deasserting RX_ACK");
        RXM_rx_ack = 0;

        $display("TXM: waiting for tx_fail or tx_succ");
        while ( (TXM_tx_fail == 0) && (TXM_tx_succ == 0) ) @(negedge clock); 
        assert( TXM_tx_succ == 1) else $fatal(1);
        assert( TXM_tx_fail == 0) else $fatal(1);

        $display("SEND TX_RESP_ACK");
        TXM_tx_resp_ack = 1;

        @(negedge clock);
        TXM_tx_resp_ack = 0;
        
        for (i = 0; i < 1000; i = i + 1) begin
            @(negedge clock);
        end


        $display("@@@Passed");
        $finish;
    end
endmodule

