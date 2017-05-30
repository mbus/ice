module mbus_glitch (

    input           SYSCLK,
    input           ENABLE,
    input [31:0]    GLITCH_CYCLES,

    //mbus lines
    input           CIN,
    input           DIN,
    output reg      DOUT
    );
    

    //interrupt detector
    wire                last_clk;
    wire                int_flag;
    reg                 int_flag_reset;

    mbus_swapper ms0 (
        .CLK(CIN),
        .RESETn(ENABLE),
        .DATA(DIN),
        .INT_FLAG_RESETn(~int_flag_reset),
        .LAST_CLK(last_clk),
        .INT_FLAG(int_flag)
    );

    // state 
    parameter STATE_IDLE = 0;
    parameter STATE_INTER_CLK_HIGH = STATE_IDLE + 1;
    parameter STATE_INTER_DONE= STATE_INTER_CLK_HIGH + 1;
    parameter STATE_INTER_CLK_LOW = STATE_INTER_DONE + 1;
    parameter STATE_INTER_CLK_HIGH2 =  STATE_INTER_CLK_LOW + 1;
    parameter STATE_GLITCH =  STATE_INTER_CLK_HIGH2 + 1;

    parameter STATE_MAX = STATE_GLITCH+1;
    parameter STATE_SZ = $clog2(STATE_MAX);

    reg [STATE_SZ:0]    state;
    reg [STATE_SZ:0]    next_state;
  
    reg [31:0]          glitch_timer, next_glitch_timer;

    always @(posedge SYSCLK) begin
        if (~ENABLE) begin
            state <= STATE_IDLE;
            glitch_timer <= GLITCH_CYCLES;
        end
        else begin
            state <= next_state;
            glitch_timer <= next_glitch_timer;
        end
    end

    always @* begin

        next_state = state;
        DOUT = DIN;
        int_flag_reset = 0;
        next_glitch_timer = glitch_timer;

        case(state)

            STATE_IDLE: begin
                if (int_flag) begin
                    next_state = STATE_INTER_CLK_HIGH;
                end
            end

            STATE_INTER_CLK_HIGH: begin
                if (CIN == 0) next_state = STATE_INTER_CLK_LOW;
            end

            STATE_INTER_CLK_LOW: begin
                DOUT = 1;
                int_flag_reset = 1;
                // internal clk vs mbus clk
                next_glitch_timer = 32'd30;
                if (CIN == 1) next_state = STATE_INTER_CLK_HIGH2;
            end

            STATE_INTER_CLK_HIGH2: begin
                DOUT = 1;
                if (glitch_timer == 0) begin
                    next_state = STATE_GLITCH;
                    next_glitch_timer = GLITCH_CYCLES;
                end else next_glitch_timer = glitch_timer - 1;
            end

            STATE_GLITCH: begin
                //want to go log just before the negedge of CIN
                DOUT = 0;
                if ( glitch_timer ==  0) next_state = STATE_IDLE;
                else next_glitch_timer = glitch_timer - 1;
            end
        endcase
    end

endmodule
 

    


