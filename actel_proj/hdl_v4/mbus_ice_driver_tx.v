module mbus_ice_driver_tx (
    input               clk,
    input               reset,

    //bus interface stuff
    input               tx_frame_valid,
    input               tx_char_valid,
    input [7:0]         tx_char,
    input               tx_char_pending,
    output              tx_char_advance,

    //mbus transmit stuff
    output reg [31:0]   tx_mbus_txaddr,
    output reg [31:0]   tx_mbus_txdata,
    output reg          tx_mbus_txreq,
    output reg          tx_mbus_txpend,
    input               tx_mbus_txack,
    input               tx_mbus_txfail,
    input               tx_mbus_txsucc,
    output reg          tx_mbus_txresp_ack,

    //ack/nak generation after the tx is finished
    output reg          tx_gen_ack,
    output reg          tx_gen_nak,
    input               tx_acknak_valid
    );


// Transmit states, some are fairly redundant
parameter ST_TX_IDLE = 0;
parameter ST_TX_FRAME_VALID = 1;
parameter ST_TX_SHIFT_ADDR0 = 2;
parameter ST_TX_SHIFT_ADDR1 = 3;
parameter ST_TX_SHIFT_ADDR2 = 4;
parameter ST_TX_SHIFT_ADDR3 = 5;
parameter ST_TX_SHIFT_DATA0 = 6;
parameter ST_TX_SHIFT_DATA1 = 7;
parameter ST_TX_SHIFT_DATA2 = 8;
parameter ST_TX_SHIFT_DATA3 = 9;
parameter ST_TX_WAIT        = 10; //a
parameter ST_TX_TXREQ       = 11; //b
parameter ST_TX_TXACK       = 12; //c
parameter ST_TX_TXSUCC      = 13; //d
parameter ST_TX_RESULT      = 14; //e
parameter ST_TX_SZ = $clog2(ST_TX_RESULT);

//transmit state machine
reg [ST_TX_SZ-1:0]      tx_state;
reg [ST_TX_SZ-1:0]      tx_next_state;


//translate the bus interfaces 8 bit interface to the mbus 32-bit
reg                     tx_mbus_txaddr_shift;
reg                     tx_mbus_txdata_shift;


always @(posedge clk) begin
    if (reset) begin
        tx_state <= `SD ST_TX_IDLE;
        tx_mbus_txaddr <= `SD 32'h0;
        tx_mbus_txdata <= `SD 32'h0;
    end else begin
        tx_state <= `SD tx_next_state;
        if (tx_mbus_txaddr_shift) 
            tx_mbus_txaddr <= {tx_mbus_txaddr[23:0],tx_char};
        if (tx_mbus_txdata_shift)
            tx_mbus_txdata <= {tx_mbus_txdata[23:0],tx_char};
    end
end

assign tx_char_advance = tx_mbus_txaddr_shift | tx_mbus_txdata_shift;

always @* begin
    tx_next_state = tx_state;
    tx_mbus_txaddr_shift = 0;
    tx_mbus_txdata_shift = 0;
    tx_mbus_txreq = 0;
    tx_mbus_txpend = 0;
    tx_gen_ack = 0;
    tx_gen_nak = 0;
    tx_mbus_txresp_ack = 0;

    case (tx_state)
        ST_TX_IDLE: begin
            if (tx_frame_valid)
                tx_next_state = ST_TX_SHIFT_ADDR0;
        end

        ST_TX_SHIFT_ADDR0: begin 
            tx_mbus_txaddr_shift = tx_char_valid;
            if (tx_char_valid == 1) begin
                tx_next_state = ST_TX_SHIFT_ADDR1;
            end
        end

        ST_TX_SHIFT_ADDR1: begin 
            tx_mbus_txaddr_shift = tx_char_valid;
            if (tx_char_valid == 1) begin
                tx_next_state = ST_TX_SHIFT_ADDR2;
            end
        end
        
        ST_TX_SHIFT_ADDR2: begin 
            tx_mbus_txaddr_shift = tx_char_valid;
            if (tx_char_valid == 1) begin
                tx_next_state = ST_TX_SHIFT_ADDR3;
            end
        end

        ST_TX_SHIFT_ADDR3: begin 
            tx_mbus_txaddr_shift = tx_char_valid;
            if (tx_char_valid == 1) begin
                tx_next_state = ST_TX_SHIFT_DATA0;
            end
        end

        ST_TX_SHIFT_DATA0: begin 
            tx_mbus_txdata_shift = tx_char_valid;
            if (tx_char_valid == 1) begin
                tx_next_state = ST_TX_SHIFT_DATA1;
            end
        end

        ST_TX_SHIFT_DATA1: begin 
            tx_mbus_txdata_shift = tx_char_valid;
            if (tx_char_valid == 1) begin
                tx_next_state = ST_TX_SHIFT_DATA2;
            end
        end
        
        ST_TX_SHIFT_DATA2: begin 
            tx_mbus_txdata_shift = tx_char_valid;
            if (tx_char_valid == 1) begin
                tx_next_state = ST_TX_SHIFT_DATA3;
            end
        end

        ST_TX_SHIFT_DATA3: begin 
            tx_mbus_txdata_shift = tx_char_valid;
            if (tx_char_valid == 1) begin
                tx_next_state = ST_TX_WAIT;
            end
        end

        ST_TX_WAIT: begin
            //stupid state that waits for a frame to complete
            tx_next_state = ST_TX_TXREQ;
        end
        
        ST_TX_TXREQ: begin 
            tx_mbus_txreq = 1;
            tx_mbus_txpend = tx_char_pending;
            if (tx_mbus_txack == 1) begin
                tx_next_state = ST_TX_TXACK;
            end
        end 

        ST_TX_TXACK: begin  //c
            if (tx_mbus_txack == 0) begin
                if (tx_char_pending) 
                    tx_next_state = ST_TX_SHIFT_DATA0;
                else
                    tx_next_state = ST_TX_TXSUCC;
            end
        end
                
        ST_TX_TXSUCC: begin  //d
            if (tx_mbus_txsucc == 1) begin
                tx_gen_ack = 1;
                tx_next_state = ST_TX_RESULT;
            end else if (tx_mbus_txfail == 1) begin
                tx_gen_nak = 1;
                tx_next_state = ST_TX_RESULT;
            end
        end 

        ST_TX_RESULT: begin  //e
            tx_mbus_txresp_ack = 1;
            if(tx_acknak_valid == 1'b0) begin
				tx_next_state = ST_TX_IDLE;
            end
        end 

    endcase
end //always @*



endmodule
