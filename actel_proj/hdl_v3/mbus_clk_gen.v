
module mbus_clk_gen(
	input sys_clk,
	input reset,
	input [15:0] clk_div,
	output reg mbus_clk
);

reg [15:0] div_ctr;

always @(posedge sys_clk) begin
	if(reset) begin
		div_ctr <= #1 16'd0;
		mbus_clk <= #1 1'b0;
	end else begin
		div_ctr <= #1 div_ctr + 16'd1;
		if(div_ctr == clk_div) begin
			div_ctr <= #1 16'd0;
			mbus_clk <= #1 ~mbu_clk;
		end
	end
end

endmodule
