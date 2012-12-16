module basics_int(
	input clk,
	input rst,

	//Immediates from bus controller
	input generate_nak,

	//Master input bus
	input [7:0] ma_data,
	input ma_data_valid,
	input ma_frame_valid,
	inout sl_overflow,

	//Slave output bus
	inout [7:0] sl_data,
	output sl_arb_request,
	input sl_arb_grant,
	input sl_data_latch,
	
	output [7:0] debug
);

parameter VERSION_MAJOR = 8'h00;
parameter VERSION_MINOR = 8'h00;

reg [7:0] ma_addr;
wire [7:0] local_sl_data;
reg [7:0] local_data;
reg [15:0] version_in;
reg local_frame_valid;
wire local_data_latch, local_data_overflow;

//State machine locals
reg [7:0] latched_eid;
reg latch_eid;

//Only drive the shared slave bus lines when we've won arbitration
//NOTE: We assume that this module should always be able to handle the traffic.  If not, we'll miss NAKs, etc.
assign sl_overflow = (sl_arb_grant) ? 1'b0 : 1'bz;
assign sl_data = (sl_arb_grant) ? local_sl_data : 8'bzzzzzzzz;

//Ack generator is used to easily create ACK & NAK sequences
reg ackgen_generate_ack, ackgen_generate_nak;
wire [7:0] ack_message_data;
wire ack_message_data_valid;
wire ack_message_frame_valid;
ack_generator ag0(
	.clk(clk),
	.reset(rst),
	
	.generate_ack(ackgen_generate_ack),
	.generate_nak(ackgen_generate_nak),
	.eid_in(latched_eid),
	
	.message_data(ack_message_data),
	.message_data_valid(ack_message_data_valid),
	.message_frame_valid(ack_message_frame_valid)
);

//Only using an output message fifo here because we should be able to keep up with requests in real-time
wire [7:0] mf_data = (ack_message_data_valid) ? ack_message_data : local_data;
wire [7:0] mf_debug;
wire mf_data_latch = local_data_latch | ack_message_data_valid;
wire mf_frame_valid = local_frame_valid | ack_message_frame_valid;
message_fifo #(8) mf1(
	.clk(clk),
	.rst(rst),
	
	.in_data(mf_data),
	.in_data_latch(mf_data_latch),
	.in_frame_valid(mf_frame_valid),
	.in_data_overflow(local_data_overflow),
	.populate_frame_length(1'b1),

	.out_data(local_sl_data),
	.out_frame_valid(sl_arb_request),
	.out_data_latch(sl_data_latch & sl_arb_grant),
	
	.debug(mf_debug)
);

//Main 'basics' state machine - takes care of version requests, query requests, and immediate NAKs
parameter STATE_IDLE = 0;
parameter STATE_SEND_EID = 1;
parameter STATE_SKIP_LENGTH = 2;
parameter STATE_NAK0 = 3;
parameter STATE_RESP_QUERY0 = 4;
parameter STATE_RESP_VER0 = 5;
parameter STATE_RESP_VER1 = 6;
parameter STATE_RESP_VER2 = 7;
parameter STATE_RESP_VER3 = 8;
parameter STATE_RESP_VER4 = 9;

reg [3:0] state, next_state;
reg [7:0] counter;
reg [2:0] latched_command;
reg send_major_ver, send_minor_ver;
reg latch_command;
reg data_counter_incr;
reg shift_ver_in;
reg new_command;

assign local_data_latch = send_major_ver | send_minor_ver;
assign debug = {version_in[11:8],version_in[3:0]};//{latch_eid,ma_data_valid,latched_eid[5:0]};//{mf_frame_valid, sl_data_latch, sl_arb_request, sl_arb_grant, mf_debug[3:0]};//{local_frame_valid, local_data_latch, send_addr, send_eid, send_nak_code, send_ack_code, send_major_ver, send_minor_ver};
wire query_request_match = new_command && (ma_addr == 8'h56);
wire ver_request_match = new_command && (ma_addr == 8'h76);
always @* begin
	next_state = state;
	latch_eid = 1'b0;
	ackgen_generate_ack = 1'b0;
	ackgen_generate_nak = 1'b0;
	send_major_ver = 1'b0;
	send_minor_ver = 1'b0;
	latch_command = 1'b0;
	data_counter_incr = 1'b1;
	local_frame_valid = 1'b0;
	shift_ver_in = 1'b0;

	case(state)
		STATE_IDLE: begin
			latch_command = 1'b1;
			if(generate_nak || query_request_match || ver_request_match) begin
				next_state = STATE_SKIP_LENGTH;
			end
		end
		
		STATE_SKIP_LENGTH: begin
			latch_eid = ma_data_valid;
			if(ma_data_valid) begin
				if(latched_command[0])
					next_state = STATE_NAK0;
				else if(latched_command[1])
					next_state = STATE_RESP_QUERY0;
				else if(latched_command[2])
					next_state = STATE_RESP_VER0;
			end
		end

		STATE_NAK0: begin
			ackgen_generate_nak = 1'b1;

			//Let's just send the EID while filling up the extra room for the length field
			next_state = STATE_IDLE;
		end

		STATE_RESP_QUERY0: begin
			ackgen_generate_ack = 1'b1;
			//TODO: Don't think this command is fully defined yet?!
			next_state = STATE_RESP_VER2;
		end

		STATE_RESP_VER0: begin
			shift_ver_in = ma_data_valid;
			data_counter_incr = ma_data_valid;
			if(counter == 8'd2 && ma_data_valid)
				next_state = STATE_RESP_VER1;
		end

		STATE_RESP_VER1: begin
			if(version_in == {VERSION_MAJOR, VERSION_MINOR}) begin
				ackgen_generate_ack = 1'b1;
				next_state = STATE_IDLE;
			end else begin
				ackgen_generate_nak = 1'b1;
				next_state = STATE_RESP_VER2;
			end
		end

		STATE_RESP_VER2: begin
			local_frame_valid = 1'b1;
			if(ack_message_frame_valid == 1'b0)
				next_state = STATE_RESP_VER3;
		end
		
		STATE_RESP_VER3: begin
			local_frame_valid = 1'b1;
			send_major_ver = 1'b1;
			next_state = STATE_RESP_VER4;
		end

		STATE_RESP_VER4: begin
			local_frame_valid = 1'b1;
			send_minor_ver = 1'b1;
			next_state = STATE_IDLE;
		end
	endcase

	//Mux the data out to the message fifo
	local_data = VERSION_MAJOR;
	if(send_minor_ver) local_data = VERSION_MINOR;
end

reg last_ma_frame_valid;
always @(posedge clk) begin
	last_ma_frame_valid <= ma_frame_valid;
	if(ma_frame_valid && ~last_ma_frame_valid) begin
		ma_addr <= ma_data;
		new_command <= 1'b1;
	end else if(ma_data_valid) begin
		new_command <= 1'b0;
	end

	if(latch_eid)
		latched_eid <= ma_data;
	
	if(next_state != state)
		counter <= 0;
	else if(data_counter_incr)
		counter <= counter + 1;

	if(shift_ver_in)
		version_in <= {version_in[7:0], ma_data};

	if(latch_command) 
		latched_command <= {ver_request_match, query_request_match, generate_nak};

	if(rst) begin
		state <= STATE_IDLE;
		counter <= 8'd0;
	end else begin
		state <= next_state;
	end
end

endmodule

