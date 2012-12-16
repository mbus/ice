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

//State machine signals
reg latch_old_head;
reg insert_in_data;
reg insert_fvbit;
reg revert_head_ptr;
reg incr_byte_ctr;
reg incr_frame_ctr;
reg insert_frame_ctr1;
reg insert_frame_ctr2;

//Inferred ram block
reg [DEPTH_LOG2-1:0] head, old_head, tail, num_valid_frames;
reg [15:0] num_frame_bytes;
wire [DEPTH_LOG2-1:0] ram_wr_addr;
wire [7:0] ram_wr_data;
wire ram_wr_latch;
ram #(9,DEPTH_LOG2) fr1(
	.clk(clk),
	.reset(rst),
	.in_data({insert_fvbit, ram_wr_data}),
	.in_addr(ram_wr_addr),
	.in_latch(ram_wr_latch),
	.out_data({sof_marker, out_data}),
	.out_addr(tail)
);

assign ram_wr_addr = (insert_frame_ctr1) ? old_head + 2 :
                     (insert_frame_ctr2) ? old_head + 3 : head;
assign ram_wr_data = (insert_frame_ctr1) ? {1'b0, num_frame_bytes[15:8]} :
                     (insert_frame_ctr2) ? {1'b0, num_frame_bytes[7:0]} : {insert_fvbit,in_data};
assign ram_wr_latch = (insert_frame_ctr1 | insert_frame_ctr2 | insert_in_data); 

reg last_frame_valid, last_out_data_latch;

assign in_data_overflow = (head == tail-1);
assign out_frame_valid = (num_valid_frames > 0) && !(sof_marker);

//Main state machine logic
parameter STATE_IDLE = 0;
parameter STATE_RECORDING_FRAME = 1;
parameter STATE_POPULATE_FLEN1 = 2;
parameter STATE_POPULATE_FLEN2 = 3;

reg [3:0] state, next_state;
always @(posedge clk) begin
	last_frame_valid <= in_frame_valid;
	last_out_data_latch <= out_data_latch;

	if(rst) begin
		state <= STATE_IDLE;
		head <= 0;
		old_head <= 0;
		tail <= 0;
		num_valid_frames <= 0;
		num_frame_bytes <= 0;
	end else begin
		state <= next_state;
	
		if(latch_old_head) begin
			old_head <= head;
			num_frame_bytes <= 1;
		end
		if(insert_in_data)
			head <= head + 1;
		if(revert_head_ptr)
			head <= old_head;
		if(incr_byte_ctr)
			num_frame_bytes <= num_frame_bytes + 1;
		if(incr_frame_ctr)
			num_valid_frames <= num_valid_frames + 1;

		if(out_data_latch)
			tail <= tail + 1;
		if(last_out_data_latch && sof_marker)
			num_valid_frames <= num_valid_frames - 1;
	end
end
always @* begin
	next_state = state;
	latch_old_head = 1'b0;
	insert_in_data = 1'b0;
	insert_fvbit = 1'b0;
	revert_head_ptr = 1'b0;
	incr_byte_ctr = 1'b0;
	incr_frame_ctr = 1'b0;
	insert_frame_ctr1 = 1'b0;
	insert_frame_ctr2 = 1'b0;

	case(state)
		STATE_IDLE: begin
			latch_old_head = 1'b1;
			if(in_frame_valid && ~last_frame_valid) begin
				insert_in_data = 1'b1;
				insert_fvbit = 1'b1;
				next_state = STATE_RECORDING_FRAME;
			end
		end
		
		STATE_RECORDING_FRAME: begin
			if(in_data_overflow) begin
				revert_head_ptr = 1'b1;
				next_state = STATE_IDLE;
			end else if(in_data_latch) begin
				incr_byte_ctr = 1'b1;
				insert_in_data = 1'b1;
			end
			if(~in_frame_valid) begin
				incr_frame_ctr = 1'b1;
				if(populate_frame_length)
					next_state = STATE_POPULATE_FLEN1;
				else
					next_state = STATE_IDLE;
			end
		end
		
		STATE_POPULATE_FLEN1: begin
			insert_frame_ctr1 = 1'b1;
			next_state = STATE_POPULATE_FLEN2;
		end
		
		STATE_POPULATE_FLEN2: begin
			insert_frame_ctr2 = 1'b1;
			next_state = STATE_IDLE;
		end
	endcase
end

endmodule

