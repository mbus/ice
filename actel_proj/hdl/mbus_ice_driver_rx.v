`include "include/ice_def.v"

module mbus_ice_driver_rx (
    input               clk,
    input               reset,

    //stuff from mbus  
    input [31:0]        mbus_rx_addr,
	input [31:0]        mbus_rx_data,
	input               mbus_rx_req, 
	output reg          mbus_rx_ack,
	input               mbus_rx_broadcast,
	input               mbus_rx_fail,
	input               mbus_rx_pend,
	input [1:0]         mbus_rx_control_bits,
    
    output reg          buffer_request,
    input               buffer_grant,
    output reg [7:0]    buffer_data,
    output reg          buffer_valid,

    input [7:0]         global_counter,
	output reg          global_counter_inc
    );

parameter RX_ST_IDLE        = 0;
parameter RX_ST_CODE        = 1;
parameter RX_ST_EID         = 2;
parameter RX_ST_DUMMY       = 3;
parameter RX_ST_ADDR0       = 4;
parameter RX_ST_ADDR1       = 5;
parameter RX_ST_ADDR2       = 6;
parameter RX_ST_ADDR3       = 7;
parameter RX_ST_DATA0       = 8;
parameter RX_ST_DATA1       = 9;
parameter RX_ST_DATA2       = 10; //a
parameter RX_ST_DATA3       = 11; //b
parameter RX_ST_PEND        = 12; //c
parameter RX_ST_PEND_ACK    = 13; //d
parameter RX_ST_PEND_WAIT   = 14; //e
parameter RX_ST_CTRL_BITS   = 15; //f
parameter RX_ST_END_ACK     = 16; //10
parameter RX_ST_SZ = $clog2(RX_ST_END_ACK+1);

reg [RX_ST_SZ-1:0]      rx_state /* synthesis syn_encoding="grey" */;
reg [RX_ST_SZ-1:0]      rx_next_state;

always @(posedge clk) begin
    if (reset) begin
        rx_state <= `SD RX_ST_IDLE;
    end else begin
        rx_state <= `SD rx_next_state;
    end
end

always @* begin
    rx_next_state = rx_state;
    buffer_request = 0;
    buffer_data = 8'hz;
    buffer_valid = 0;
    global_counter_inc = 0;
    mbus_rx_ack = 0;

    case(rx_state) 
        RX_ST_IDLE: begin 
            if (mbus_rx_fail == 1) begin
                rx_next_state = RX_ST_END_ACK;
            end else if (mbus_rx_req == 1) begin
                rx_next_state = RX_ST_CODE;
            end
        end

        RX_ST_CODE: begin 
            buffer_request = 1;
            buffer_data = 8'h62;
            //might need to wait
            if (buffer_grant == 1) 
                rx_next_state = RX_ST_EID;
        end

        RX_ST_EID: begin 
            buffer_request = 1;
            buffer_data = global_counter;
            buffer_valid = 1;
            global_counter_inc = 1;
            rx_next_state = RX_ST_DUMMY;
        end

        RX_ST_DUMMY: begin 
            buffer_request = 1;
            //just write 0 here, will get updated later
            buffer_data = 8'h0; 
            buffer_valid = 1;
            rx_next_state = RX_ST_ADDR0;
        end

        RX_ST_ADDR0: begin 
            buffer_request = 1;
            buffer_data = mbus_rx_addr[31:24];
            buffer_valid = 1;
            rx_next_state = RX_ST_ADDR1;
        end
        
        RX_ST_ADDR1: begin 
            buffer_request = 1;
            buffer_data = mbus_rx_addr[23:16];
            buffer_valid = 1;
            rx_next_state = RX_ST_ADDR2;
        end

        RX_ST_ADDR2: begin 
            buffer_request = 1;
            buffer_data = mbus_rx_addr[15:8];
            buffer_valid = 1;
            rx_next_state = RX_ST_ADDR3;
        end

        RX_ST_ADDR3: begin 
            buffer_request = 1;
            buffer_data = mbus_rx_addr[7:0];
            buffer_valid = 1;
            rx_next_state = RX_ST_DATA0;
        end

        RX_ST_DATA0: begin 
            buffer_request = 1;
            buffer_data = mbus_rx_data[31:24];
            buffer_valid = 1;
            rx_next_state = RX_ST_DATA1;
        end

        RX_ST_DATA1: begin 
            buffer_request = 1;
            buffer_data = mbus_rx_data[23:16];
            buffer_valid = 1;
            rx_next_state = RX_ST_DATA2;
        end

        RX_ST_DATA2: begin 
            buffer_request = 1;
            buffer_data = mbus_rx_data[15:8];
            buffer_valid = 1;
            rx_next_state = RX_ST_DATA3;

        end

        RX_ST_DATA3: begin 
            buffer_request = 1;
            buffer_data = mbus_rx_data[7:0];
            buffer_valid = 1;
            rx_next_state = RX_ST_PEND;
        end
        
        RX_ST_PEND: begin
            buffer_request = 1;
            if (mbus_rx_pend == 1)
                rx_next_state = RX_ST_PEND_ACK;
            else
                rx_next_state = RX_ST_CTRL_BITS;
        end

        RX_ST_PEND_ACK: begin
            buffer_request = 1; 
            mbus_rx_ack = 1;
            rx_next_state = RX_ST_PEND_WAIT;
        end

        RX_ST_PEND_WAIT: begin
            buffer_request = 1; //hold the buffer until we get another packet
            if (mbus_rx_req == 1)
                rx_next_state = RX_ST_DATA0;
        end

        RX_ST_CTRL_BITS: begin 
            buffer_request = 1;
            buffer_data = {5'b00000, mbus_rx_broadcast, mbus_rx_control_bits};
            buffer_valid = 1;
            rx_next_state = RX_ST_END_ACK;
        end

        RX_ST_END_ACK: begin
            mbus_rx_ack = 1;
            rx_next_state = RX_ST_IDLE; 
        end
        
    endcase
end

endmodule
