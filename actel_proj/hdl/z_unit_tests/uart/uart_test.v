
`timescale 1ns/1ps

`define SD #125

module testbench;

    //
    // SIGNALS for ACTUAL UART
    // 

    //inputs
    reg         reset;
    reg         clock;
    reg [15:0]  baud_div;
    wire        rx_in; //driven by uart_test

    reg         tx_latch;
    reg [7:0]   tx_data;

    //outputs
    wire        tx_out; // UART_TX_LINE
    wire        tx_empty; // ready for new TX_DATA

    wire [7:0]  rx_data; //
    wire        rx_latch;


    //
    // TEST EXPECTED OUTPUTS
    //
    reg [7:0]   expect_rx_data;
    reg         expect_rx_latch;

    wire correct_rx_data = expect_rx_data == rx_data;
    wire correct_rx_latch = expect_rx_latch == rx_latch;


    //
    // SIGNALS FOR TEST UART
    //
    reg [15:0]      test_baud_div;
    
    reg             test_tx_latch;
    reg [7:0]       test_tx_data;
    wire            test_tx_empty;

    wire [7:0]      test_rx_data;
    wire            test_rx_latch;

    // 
    // SIGNALS FOR TESTING
    //
    integer i;

    //
    // ACTUAL UART
    // 
    uart uart0 (

        .reset(reset),
        .clk(clock),
        .baud_div (baud_div),

        .rx_in(rx_in),
        .tx_out(tx_out),

        .tx_latch(tx_latch),
        .tx_data(tx_data),
        .tx_empty(tx_empty),

        .rx_data(rx_data),
        .rx_latch(rx_latch)
    );        

    //
    // TEST UART
    //
    uart uart_tester(
        .reset(reset), 
        .clk(clock),
        .baud_div( test_baud_div), 

        .rx_in(tx_out), 
        .tx_out(rx_in),

        .tx_latch(test_tx_latch), 
        .tx_data (test_tx_data), 
        .tx_empty( test_tx_empty), 

        .rx_data(test_rx_data), 
        .rx_latch(test_rx_latch) 
    );



    always @(posedge clock)
    begin
        if (!correct_rx_latch)
        begin
            $display("rx_data=%h, expected=%h", rx_data , expect_rx_data);
            $display("rx_latch=%h, expected=%h", rx_latch , expect_rx_latch);
            $display("@@@FAILED");
            $finish;
        end
    end

    always
    begin
        #1000
        clock = ~clock;
    end

    initial
    begin
	$monitor("rx_data:%h, rx_latch:%h", rx_data, rx_latch);

        clock = 1'h0;
        reset = 1'h1;
        baud_div = 16'h10;
        tx_latch = 1'h0;
        tx_data = 8'h0;


        expect_rx_data = 8'h0;
        expect_rx_latch = 1'h0;
         
        test_baud_div = 16'h173;
        test_tx_latch = 1'h0;
        test_tx_data = 8'h0;

        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
            reset = 1'h0;

        @(negedge clock); 
            test_tx_latch = 1'h1;
            test_tx_data = 8'h56;
        @(negedge clock); 
            test_tx_latch = 1'h0;

        while (test_tx_empty == 0)
        begin 
            @(negedge clock);
        end
        @(negedge clock); 

        for (i = 0; i < 1000; i = i + 1)
        begin
            @(negedge clock);
        end

        @(negedge clock);
            test_baud_div = 8'h10;
        @(negedge clock); 
            test_tx_latch = 1'h1;
            test_tx_data = 8'h56;
        @(negedge clock); 
            test_tx_latch = 1'h0;
        while (test_tx_empty == 0)
        begin 
            @(negedge clock);
        end
        @(negedge clock); 
            test_tx_latch = 1'h0;

        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        expect_rx_latch = 1'h1;
        @(negedge clock); 
        expect_rx_latch = 1'h0;
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        

        $display("@@@Passed");
        $finish;
    end
endmodule

