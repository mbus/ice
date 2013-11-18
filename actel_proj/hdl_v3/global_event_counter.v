`include "include/ice_def.v"

module global_event_counter(
	input clk,
	input rst,
	
	input ctr_incr,
	output reg [7:0] counter_out
);

always @(posedge clk) begin
	if(rst) begin
		counter_out <= `SD 0;
	end else begin
		if(ctr_incr)
			counter_out <= `SD counter_out + 8'd1;
	end
end

endmodule
