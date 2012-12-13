module message_fifo(
	input clk,
	input rst,

	input [7:0] in_data,
	input in_data_latch,
	input in_frame_valid,
	output in_data_overflow,
	input populate_frame_length,

	output [7:0] out_data,
	output out_frame_valid,
	input out_data_latch
);
parameter DEPTH_LOG2=8;
parameter DEPTH = (1 << DEPTH_LOG2);

wire sof_marker;

reg [DEPTH_LOG2-1:0] head, old_head, tail, num_valid_frames;
reg [15:0] num_frame_bytes;
reg [8:0] fifo_ram [DEPTH-1:0];
reg recording_frame, dispensing_frame, last_frame_valid, last_out_data_latch;
reg after_frame_count;

assign in_data_overflow = (head == tail-1);
assign out_data = fifo_ram[tail][7:0];
assign sof_marker = fifo_ram[tail][8];
assign out_frame_valid = (num_valid_frames > 0) && !(sof_marker);
always @(posedge clk) begin
	dispensing_frame <= 1'b0; //TODO: Completely forgot what this is for...
	last_frame_valid <= in_frame_valid;
	last_out_data_latch <= out_data_latch;

	if(rst) begin
		head <= 0;
		old_head <= 0;
		tail <= 0;
		num_valid_frames <= 0;
		recording_frame <= 1'b0;
		after_frame_count <= 2'd3;
		num_frame_bytes <= 0;
	end else begin
		if(in_frame_valid && ~last_frame_valid) begin
			recording_frame <= 1'b1;
			old_head <= head;
			fifo_ram[head] <= {1'b1, in_data}; //The first byte will be the event id for every message
			num_frame_bytes <= 1;
			head <= head + 1;
		end else if(recording_frame) begin
			if(in_data_overflow) begin
				recording_frame <= 1'b0;
				head <= old_head;
			end else if(in_data_latch) begin
				fifo_ram[head] <= {1'b0, in_data};
				head <= head + 1;
				num_frame_bytes <= num_frame_bytes + 1;
			end

			if(~in_frame_valid) begin
				recording_frame <= 1'b0;
				num_valid_frames <= num_valid_frames + 1;
				after_frame_count <= 2'd0;
			end
		end else if(after_frame_count == 2'd0 && populate_frame_length) begin
			fifo_ram[old_head+2] <= num_frame_bytes[15:8];
		end else if(after_frame_count == 2'd1 && populate_frame_length) begin
			fifo_ram[old_head+3] <= num_frame_bytes[7:0];
		end


		if(out_data_latch)
			tail <= tail + 1;
		if(last_out_data_latch && sof_marker)
			num_valid_frames <= num_valid_frames - 1;
	end
end

endmodule

