

module mbus_err_generator (
    input       ENABLE,
    //mbus lines
    input       CIN,
    input       DIN,
    output reg  DOUT
    );

    wire        last_clk;
    wire        int_flag;
    reg         int_flag_reset;

    parameter STATE_IDLE = 0;
    parameter STATE_INTER = 1;
    parameter STATE_CTRL0 = 2;
    parameter STATE_CTRL1 = 3;

    reg [1:0]   state;
    reg [1:0]   next_state;

    mbus_swapper ms0 (
        .CLK(CIN),
        .RESETn(ENABLE),
        .DATA(DIN),
        .INT_FLAG_RESETn(~int_flag_reset),
        .LAST_CLK(last_clk),
        .INT_FLAG(int_flag)
    );

    always @(negedge CIN) begin
        if (~ENABLE) begin
            state <= STATE_IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @* begin
        next_state = state;
        DOUT = DIN;
        int_flag_reset = 0;
        
        case(state)

            STATE_IDLE: begin //0
                if (int_flag) begin
                    next_state = STATE_INTER;
                end
            end

            STATE_INTER: begin //1
                next_state = STATE_CTRL0;
                DOUT = 1;
            end

            STATE_CTRL0: begin
                next_state = STATE_CTRL1;   
                DOUT = 0;
            end

            STATE_CTRL1: begin
                next_state = STATE_IDLE;
                DOUT = 1;
                int_flag_reset = 1;
            end
        endcase
    end
endmodule


