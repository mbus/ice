
`timescale 1ns/1ps

`define SD #125
`define SIM_FLAG

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
    // SIGNALS for the MBUS
    //
    reg         master_en;
    reg         mbus_snoop_enabled;
    reg [19:0]  address;
    reg [3:0]   assigned_addr_in;
    reg         assigned_addr_valid;

    reg         clkin;
    reg         din;

    reg [31:0]  tx_addr;
    reg [31:0]  tx_data;
    reg         tx_pend;
    reg         tx_req;
    reg         tx_priority;
    reg         tx_resp_ack;
    
    reg         rx_ack;
    
    wire [3:0]  assigned_addr_out;
    wire        assigned_addr_write;
    wire        assigned_addr_invalidN;

    wire        clkout;
    wire        dout;

    wire        tx_ack;
    wire        tx_fail;
    wire        tx_succ;

    wire [31:0] rx_addr;
    wire [31:0] rx_data;
    wire        rx_req;
    wire        rx_broadcast;
    wire        rx_fail;
    wire        rx_pend;

    wire [1:0]  ice_export_control_bits;

    //
    // ACTUAL MBUS
    //
    mbus_general_layer_wrapper mglw0(
        .CLK_EXT(mbus_clk),
        .MASTER_EN(master_en),
        .mbus_snoop_enabled(mbus_snoop_enabled),
        .ADDRESS(address),
        .ASSIGNED_ADDR_IN(assigned_addr_in),
        .ASSIGNED_ADDR_OUT(assigned_addr_out),
        .ASSIGNED_ADDR_VALID(assigned_addr_valid),
        .ASSIGNED_ADDR_WRITE(assigned_addr_write),
        .ASSIGNED_ADDR_INVALIDn(assigned_addr_invalidN),
        .CLKIN(clkin),
        .CLKOUT(clkout),
        .RESETn(resetN),
        .DIN(din),
        .DOUT(dout),
        .TX_ADDR(tx_addr),
        .TX_DATA(tx_data), 
        .TX_PEND(tx_pend), 
        .TX_REQ(tx_req), 
        .TX_PRIORITY(tx_priority),
        .TX_ACK(tx_ack), 
        .RX_ADDR(rx_addr), 
        .RX_DATA(rx_data), 
        .RX_REQ(rx_req), 
        .RX_ACK(rx_ack), 
        .RX_BROADCAST(rx_broadcast),
        .RX_FAIL(rx_fail),
        .RX_PEND(rx_pend), 
        .ice_export_control_bits(ice_export_control_bits),
        .TX_FAIL(tx_fail), 
        .TX_SUCC(tx_succ), 
        .TX_RESP_ACK(tx_resp_ack)

    );

    // 
    // SIGNALS FOR TESTING
    //
    integer i;

    assign #10000 clkin = clkout;
    assign #10000 din = dout;

   
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
        $monitor("CLKOUT:%h, DOUT:%h", clkout, dout);

        clock = 0;
        mbus_clk_div = 6'h20;
        reset = 1;
        master_en = 1;
        mbus_snoop_enabled = 0;
        address = 20'h0A;
        assigned_addr_in = 4'hB;
        assigned_addr_valid = 0;

        tx_addr = 32'haddaadda;
        tx_data = 32'hdadadada;
        tx_pend = 0;
        tx_req = 0;
        tx_priority = 0;
        tx_resp_ack = 0;
        
        rx_ack= 0;

        @(negedge clock); 

        @(negedge clock); 
        reset = 0;

        @(negedge clock); 
        $display("fist packet, asserting TX_REQ");
        assert( tx_ack == 0) else $fatal(1);
        tx_req = 1;
        
        while( tx_ack == 0) @(negedge clock); 
        $display("Got TX_ACK, Deasserting TX_REQ");
        tx_req = 0;

        // nobody to ACK it, should fail
        while (tx_fail == 0) @(negedge clock); 
        assert( tx_succ == 0) else $fatal(1);
        tx_resp_ack = 1;

        @(negedge clock);
        tx_resp_ack = 0;

        for (i = 0; i < 1000; i = i + 1) begin
            @(negedge clock);
        end

        @(negedge clock);
        $display("Second packet, asserting TX_REQ and TX_PEND");
        tx_req = 1;
        tx_pend = 1;
        tx_data = 32'hF000000F;

        $display("Waiting for TX_ACK to go high");
        while(tx_ack == 0) @(negedge clock); 

        $display("TX_ACK is high, TX_REQ goes low, TX_PEND stays high");
        tx_req = 0;
        tx_pend = 1; // keep this high

        $display("Waiting for TX_ACK to go low");
        while (tx_ack == 1) @(negedge clock);
        
        $display("TX_ACK is low, setup for next word");
        tx_req = 1;
        tx_pend = 1; // keep this high
        tx_data = 32'hF0F0F0F0;

        $display("Waiting for TX_ACK to go high");
        while(tx_ack == 0) @(negedge clock); 

        $display("TX_ACK is high, TX_REQ goes low, TX_PEND stays high");
        tx_req = 0;
        tx_pend = 1; // keep this high

        $display("Waiting for TX_ACK to go low");
        while (tx_ack == 1) @(negedge clock);

        $display("TX_ACK low, setup for last word");
        tx_req = 1;
        tx_pend = 0; //last word, now this goes low
        tx_data = 32'h0000000F;

        $display("Waiting for TX_ACK to go high");
        while(tx_ack == 0) @(negedge clock); 

        $display("Got final TX_ACK, deasserting TX_REQ");
        tx_req = 0;
        
        $display("waiting for tx_fail");
        while (tx_fail == 0) @(negedge clock); 
        assert( tx_succ == 0) else $fatal(1);

        $display("SEND TX_RESP_ACK");
        tx_resp_ack = 1;

        @(negedge clock);
        tx_resp_ack = 0;
        
        for (i = 0; i < 1000; i = i + 1) begin
            @(negedge clock);
        end

        $display("@@@Passed");
        $finish;
    end
endmodule

