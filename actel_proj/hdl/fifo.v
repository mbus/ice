module fifo(clk,reset,in,in_latch,out,out_latch,out_valid);
//User-defined parameters
parameter DATA_WIDTH = 8;
parameter DEPTH_LOG2 = 4;
parameter DEPTH = (1 << DEPTH_LOG2);

//Ports
input clk;
input reset;
input [DATA_WIDTH-1:0] in;
input in_latch;
output [DATA_WIDTH-1:0] out;
input out_latch;
output out_valid;

//Locals
reg [DATA_WIDTH-1:0] ram [DEPTH-1:0];
reg [DEPTH_LOG2-1:0] read_ptr;
reg [DEPTH_LOG2-1:0] write_ptr;

assign out_valid = (read_ptr != write_ptr);
assign out = ram[read_ptr];

always @(posedge clk) begin
	if(reset) begin
		read_ptr <= 0;
		write_ptr <= 0;
	end else begin
		if(in_latch) begin
			ram[write_ptr] <= in;
			write_ptr <= write_ptr + 1;
		end
		if(out_latch && out_valid) begin
			read_ptr <= read_ptr + 1;
		end
	end
end

endmodule
