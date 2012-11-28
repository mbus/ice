module fifo(clk,reset,in,in_latch,out,out_latch,out_valid,out_flag_count);
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
output reg [DEPTH_LOG2-1:0] out_flag_count;

//Locals
reg [DATA_WIDTH-1:0] ram [DEPTH-1:0];
reg [DEPTH_LOG2-1:0] read_ptr;
reg [DEPTH_LOG2-1:0] write_ptr;

assign out_valid = (read_ptr != write_ptr);
assign out = ram[read_ptr];

assign in_valid = ((write_ptr + 1) != read_ptr); //Protect against overflows

always @(posedge clk) begin
	if(reset) begin
		read_ptr <= 0;
		write_ptr <= 0;
		out_flag_count <= 0;
	end else begin
		if(in_latch && in_valid) begin
			ram[write_ptr] <= in;
			write_ptr <= write_ptr + 1;
			if(in[DATA_WIDTH-1])
				out_flag_count <= out_flag_count + 1;
		end
		if(out_latch && out_valid) begin
			read_ptr <= read_ptr + 1;
			if(out[DATA_WIDTH-1])
				out_flag_count <= out_flag_count - 1;
		end
	end
end

endmodule
