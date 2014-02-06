`include "include/ice_def.v"

module por(
	input clk,
	inout PAD,
    input PB_RESET,
	output reg reset
);
	
//This circuit follows the design guidelines from http://www.actel.com/documents/LPF_AC380_AN.pdf
// to make a simple PoR circuit using just a single external pull-up resistor (~100kOhm)

wire RST_p;
`ifdef SIM_FLAG
	assign RST_p = PAD;
`else
	BIBUF b0(
		.PAD(PAD),
		.Y(RST_p),
		.D(1'b0),
		.E(PB_RESET)
	);
`endif

reg [15:0] counter;
always @(posedge clk or posedge RST_p) begin
	if(RST_p) begin
        counter <= `SD 16'd0;
    	reset <= `SD 1'b0;
	end else begin
        if(counter < 16'hffff) begin
            counter <= `SD counter + 16'd1;
            if(counter > 16'h7FFF)
                reset <= `SD 1'b1;
        end else begin
            reset <= `SD 1'b0;
        end
    end
end

endmodule
