module clock_divider(
	input reset,
	input clk_in,
	output reg clk_out
);

parameter DIVIDE_FACTOR = 8;

reg [31:0] div_counter;
always @(posedge clk_in) begin
	if(reset) begin
		div_counter <= 32'd0;
		clk_out <= 1'b0;
	end else begin
		div_counter <= div_counter + 32'd1;
		if(div_counter == DIVIDE_FACTOR/2) begin
			div_counter <= 32'd0;
			clk_out <= ~clk_out;
		end
	end
end

endmodule
