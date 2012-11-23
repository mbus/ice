module priority_select(
	input clk,
	input rst,
	input enable,
	input latch,
	
	input requests,
	output grants,
	output granted
);
parameter WIDTH=8;

wire [WIDTH-1:0] requests;
reg [WIDTH-1:0] grants, temp_grants;

assign granted = (grants & requests) > 0;

integer ii;
reg temp_granted;
always @* begin
	temp_grants = 0;
	temp_granted = 1'b0;
	
	//Only grant one request, and only if the priority selector is enabled...
	if(enable) begin
		for(ii = 0; ii < WIDTH; ii=ii+1) begin
			if(requests[ii] && ~temp_granted) begin
				temp_grants[ii] = 1'b1;
				temp_granted = 1'b1;
			end
		end
	end
end

always @(posedge clk) begin
	if(rst) begin
		grants <= 0;
	end else begin
		if(latch) begin
			grants <= temp_grants;
		end
	end
end

endmodule

