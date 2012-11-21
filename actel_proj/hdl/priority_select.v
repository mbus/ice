module priority_select(
	input enable,
	
	input requests,
	output grants
);
parameter WIDTH=8;

wire [WIDTH-1:0] requests;
reg [WIDTH-1:0] grants;

integer ii;
reg granted;
always @* begin
	grants = 0;
	granted = 1'b0;
	
	//Only grant one request, and only if the priority selector is enabled...
	if(enable) begin
		for(ii = 0; ii < WIDTH; ii=ii+1) begin
			if(requests[ii] && ~granted) begin
				grants[ii] = 1'b1;
				granted = 1'b1;
			end
		end
	end
end

endmodule
