`include "include/ice_def.v"

module i2c_stub (

    input           reset,

    inout           sda,
    input           scl,

    input [7:0]     ADDR1,
    input [7:0]     DATA1,
    input [7:0]     ADDR2,
    input [7:0]     DATA2,
    input           DATA2_WR

    );

parameter   ST_IDLE             = 0;
parameter   ST_ADDR1            = 1;
parameter   ST_ADDR1_DATA       = 2;
parameter   ST_RESTART          = 3;
parameter   ST_ADDR2            = 4;
parameter   ST_ADDR2_DATA_RD    = 5;
parameter   ST_ADDR2_DATA_WR    = 6;
parameter   ST_STOP             = 7;
parameter ST_TX_SZ          = $clog2(ST_STOP+1);

reg [ST_TX_SZ-1:0]      state  ;
reg [ST_TX_SZ-1:0]      nstate ;


reg [7:0]               sda_data; //our address/data buffer
reg [7:0]               sda_cnt; //oversized counter
reg [7:0]               n_sda_cnt; //next oversized counter

reg                     sda_wr_enable; //write to sda line
reg                     sda_wr_bit; // bit to write to sda line
reg                     sda_wr_enable_latch; //write to sda line
reg                     sda_wr_bit_latch; // bit to write to sda line

////////////////////////////////////////
//  CLOCK
////////////////////////////////////////   
always @(posedge scl or posedge reset) begin
    if (reset) begin
        state  <= `SD ST_IDLE;
        sda_data <= `SD 8'h0;
    end else begin
        state <= `SD nstate;
        sda_data <= `SD {sda_data[6:0] , sda };
        sda_cnt <= `SD n_sda_cnt;
    end
end

////////////////////////////////////////
//  SDA is wierd
////////////////////////////////////////   
assign sda = sda_wr_enable_latch ? sda_wr_bit_latch : 1'hz; 

always @(negedge scl or posedge reset) begin
    if (reset) begin
        sda_wr_enable_latch <= 1'b0;
        sda_wr_bit_latch <= 1'bz;
    end else begin
        sda_wr_enable_latch <= sda_wr_enable;
        sda_wr_bit_latch <= sda_wr_bit;
    end
end

////////////////////////////////////////
//  Combinational
////////////////////////////////////////   
always @* begin
    nstate = state;    
    n_sda_cnt = sda_cnt - 1;
    sda_wr_enable = 1'h0;
    sda_wr_bit = 1'hz;

    case (state) 
        ST_IDLE: begin
            n_sda_cnt = sda_cnt;
            //transmission starts with low sda
            if (sda == 1'h0) begin
                nstate = ST_ADDR1;
                n_sda_cnt = 7;  //read data on step 8
            end
        end

        ST_ADDR1: begin
            if (sda_cnt == 0) begin
                $display("\t\t\tsda_data: %h", sda_data);
                assert( sda_data == ADDR1) else $fatal(1);

                nstate = ST_ADDR1_DATA;
                n_sda_cnt = 8; // 1 ACK + 7 bit shift (read on DATA)
                sda_wr_enable = 1'h1;
                sda_wr_bit = 1'h0;
            end
        end

        ST_ADDR1_DATA: begin
            if (sda_cnt == 0) begin
                $display("\t\t\tsda_data: %h", sda_data);
                assert( sda_data == DATA1) else $fatal(1);

                nstate = ST_ADDR2;
                n_sda_cnt = 9; // 1 RESTART + ACK + 7 bit shift (read on ADDR2)
                sda_wr_enable = 1'h1;
                sda_wr_bit = 1'h0;

            end
        end

        ST_ADDR2: begin
            if (sda_cnt == 0) begin
                $display("\t\t\tsda_data: %h", sda_data);
                assert( sda_data == ADDR2) else $fatal(1);

                if ( DATA2_WR ) begin
                    nstate = ST_ADDR2_DATA_WR; //we're writing data
                end else begin // We're reading data
                    nstate = ST_ADDR2_DATA_RD;
                end

                n_sda_cnt = 8; // 1 ACK + 7 bit shift + ACK (read on DATA2)
                sda_wr_enable = 1'h1;
                sda_wr_bit = 1'h0;

            end
        end

        ST_ADDR2_DATA_RD: begin
            //not well tested
            if (sda_cnt == 0) begin
                $display("\t\t\tsda_data: %h", sda_data);
                assert( sda_data == DATA2) else $fatal(1);
            
                sda_wr_enable = 1'h1;
                sda_wr_bit = 1'h0;
            end else if (sda_cnt == 0) begin
                nstate = ST_STOP;
            end
        end
        
        ST_ADDR2_DATA_WR: begin
           if (sda_cnt > 0) begin
                sda_wr_enable = 1'h1;
                sda_wr_bit = DATA2[sda_cnt-1] ; //data
            end else if (sda_cnt == 0) begin
                sda_wr_enable = 1'h0; //master does ACK
                nstate = ST_STOP;
                $display("\t\t\tsda_data: %h (TX)", DATA2);
            end
        end

        ST_STOP: begin
            nstate = ST_IDLE;
        end

    endcase
end

endmodule 
