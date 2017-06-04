
`timescale 1ns/1ps

`define SD #125

module testbench;

    //
    // SIGNALS for ACTUAL UART
    // 

    //inputs
    reg         clock;
    reg         reset;

    reg         generate_ack;
    reg         generate_nak;
    reg [7:0]   eid;
    reg         message_wait;
    
    wire [7:0]  message_data;
    wire        message_data_valid;
    wire        message_frame_valid;


    // 
    // SIGNALS FOR TESTING
    //
    integer i;

    //
    // ACTUAL ACKGEN
    // 
    ack_generator ag0(
        .clk(clock),
        .reset(reset),
        .generate_ack(generate_ack),
        .generate_nak(generate_nak), 
        .eid_in(eid),
        .message_wait(message_wait),
        .message_data(message_data),
        .message_data_valid(message_data_valid),
        .message_frame_valid(message_frame_valid)
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

    always #1000 clock = ~clock;

    initial
    begin
	$monitor("message_data:%h, message_data_valid:%h message_frame_valid:%h", 
            message_data, message_data_valid, message_frame_valid);

        clock = 1'h0;
        reset = 1'h1;

        generate_ack = 0;
        generate_nak = 0;
        eid = 8'h1;
        message_wait = 0;
 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
            reset = 1'h0;

        @(negedge clock); 
            generate_ack = 1;
        @(negedge clock); 
            generate_ack = 0;
            assert( message_frame_valid == 1) else $fatal(1);
            assert( message_data_valid == 1) else $fatal(1);
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
            assert( message_data == 8'h1) else $fatal(1);
        @(negedge clock); 
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
            assert( message_frame_valid == 0) else $fatal(1);
            assert( message_data_valid == 0) else $fatal(1);

        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);

        @(negedge clock); 
            generate_nak = 1;
        @(negedge clock); 
            generate_nak = 0;
            assert( message_frame_valid == 1) else $fatal(1);
            assert( message_data_valid == 1) else $fatal(1);
            assert( message_data == 8'h1) else $fatal(1);
        @(negedge clock); 
            assert( message_data == 8'h1) else $fatal(1);
        @(negedge clock); 
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
            assert( message_frame_valid == 0) else $fatal(1);
            assert( message_data_valid == 0) else $fatal(1);

        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);



        @(negedge clock); 
            message_wait = 1;
            generate_ack = 1;
        @(negedge clock); 
            generate_ack = 0;
        @(negedge clock); 
            assert( message_frame_valid == 1) else $fatal(1);
            assert( message_data_valid == 1) else $fatal(1);
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
            assert( message_frame_valid == 1) else $fatal(1);
            assert( message_data_valid == 1) else $fatal(1);
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
            assert( message_frame_valid == 1) else $fatal(1);
            assert( message_data_valid == 1) else $fatal(1);
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
        @(negedge clock); 
            assert( message_frame_valid == 1) else $fatal(1);
            assert( message_data_valid == 1) else $fatal(1);
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
            message_wait = 0;
            assert( message_frame_valid == 1) else $fatal(1);
            assert( message_data_valid == 1) else $fatal(1);
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
            assert( message_frame_valid == 1) else $fatal(1);
            assert( message_data_valid == 1) else $fatal(1);
            assert( message_data == 8'h1) else $fatal(1);
        @(negedge clock); 
            assert( message_data == 8'h0) else $fatal(1);
        @(negedge clock); 
            assert( message_frame_valid == 0) else $fatal(1);
            assert( message_data_valid == 0) else $fatal(1);
        @(negedge clock); 

        for (i = 0; i < 100; i = i + 1)
        begin
            @(negedge clock);
        end
       

        $display("@@@Passed");
        $finish;
    end
endmodule

