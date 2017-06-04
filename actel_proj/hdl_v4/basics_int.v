`include "include/ice_def.v"

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
	input [8:0] sl_addr,
	inout [8:0] sl_tail,
	input sl_latch_tail,
	inout [8:0] sl_data,
	output sl_arb_request,
	input sl_arb_grant,
	
	//I2C settings
	output reg [7:0] i2c_speed,
	output reg [15:0] i2c_addr,
	
	//GOC settings
	output reg [31:0] goc_speed,
	output reg goc_polarity,
	output reg goc_mode,
	
	//GPIO interface
	input [23:0] gpio_read,
	output reg [23:0] gpio_level,
	output reg [23:0] gpio_direction,
	output reg [23:0] gpio_int_enable,

	//MBus settings
	output reg mbus_force_reset,
	output reg mbus_master_mode,
	output reg mbus_snoop_enabled,
	output reg [19:0] mbus_long_addr,
	output reg  [3:0] mbus_short_addr_override,
	output reg [21:0] mbus_clk_div,
	output reg mbus_tx_prio,
	
	//M3 Switch settings
	output reg M3_0P6_SW,
	output reg M3_1P2_SW,
	output reg M3_VBATT_SW,
	
	//UART settings
	output reg [15:0] uart_baud_div,
	input uart_tx_empty,
	
	output [7:0] debug
);

parameter VERSION_MAJOR = 8'h00;
parameter VERSION_MINOR = 8'h04;
	
reg [7:0] ma_addr;
wire [8:0] local_sl_data;
reg [7:0] local_data;
reg [15:0] version_in;
reg local_frame_valid;
wire local_data_latch;

//Local copies of gpio settings to avoid shift-register complications
reg [23:0] gpio_level_temp, gpio_direction_temp, gpio_int_enable_temp;

//State machine locals
reg [7:0] latched_eid;
reg latch_eid;

//Only drive the shared slave bus lines when we've won arbitration
//NOTE: We assume that this module should always be able to handle the traffic.  If not, we'll miss NAKs, etc.
wire [8:0] mf_sl_tail;
assign sl_overflow = (sl_arb_grant) ? 1'b0 : 1'bz;
assign sl_data = (sl_arb_grant) ? local_sl_data : 9'bzzzzzzzzz;
assign sl_tail = (sl_arb_grant) ? mf_sl_tail : 9'bzzzzzzzzz;

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
    
    .message_wait(1'h0),
	.message_data(ack_message_data),
	.message_data_valid(ack_message_data_valid),
	.message_frame_valid(ack_message_frame_valid)
);

//Only using an output message fifo here because we should be able to keep up with requests in real-time
wire [7:0] mf_data = (ack_message_data_valid) ? ack_message_data : local_data;
wire [7:0] mf_debug;
wire mf_data_latch = local_data_latch | ack_message_data_valid;
wire mf_frame_valid = local_frame_valid | ack_message_frame_valid;
message_fifo 
#( .DEPTH_LOG2(5) )
mf1(
	.clk(clk),
	.rst(rst),
	
	.in_data(mf_data),
	.in_data_latch(mf_data_latch),
	.in_frame_valid(mf_frame_valid),

	.tail(mf_sl_tail),
	.out_data_addr(sl_addr),
	.out_data(local_sl_data),
	.out_frame_valid(sl_arb_request),
	.latch_tail(sl_latch_tail & sl_arb_grant)
);

//Main 'basics' state machine - takes care of version requests, query requests, and immediate NAKs
parameter STATE_IDLE = 0;
parameter STATE_LATCH_EID = 1;
parameter STATE_SKIP_LENGTH = 2;
parameter STATE_NAK0 = 3;
parameter STATE_RESP_QUERY0 = 4;
parameter STATE_RESP_VER0 = 5;
parameter STATE_RESP_VER1 = 6;
parameter STATE_RESP_VER2 = 7;
parameter STATE_RESP_VER3 = 8;
parameter STATE_RESP_VER4 = 9;
parameter STATE_QUERY_PARAM0 = 10;
parameter STATE_QUERY_PARAM1 = 11;
parameter STATE_QUERY_PARAM2 = 12;
parameter STATE_QUERY_CAPABILITY = 13;
parameter STATE_SET_PARAM0 = 14;
parameter STATE_SET_PARAM1 = 15;
parameter STATE_SET_PARAM2 = 16;
parameter STATE_SET_PARAM3 = 17;

reg [4:0] state, next_state;
reg [7:0] counter;
reg [14:0] latched_command;
reg [23:0] parameter_staging;
reg send_major_ver, send_minor_ver;
reg latch_command, latch_temps;
reg data_counter_incr;
reg shift_ver_in;
reg new_command;
reg [3:0] parameter_shift_countdown;
reg store_parameter, send_parameter, shift_parameter;
reg store_to_parameter, shift_to_parameter;
reg [15:0] uart_baud_temp;
reg capability_query, send_capability, capability_incr;
reg [7:0] capability_counter;

assign local_data_latch = send_major_ver | send_minor_ver | send_parameter | send_capability;
assign debug = state;//{store_parameter,ma_data[6:0]};//{version_in[11:8],version_in[3:0]};//{latch_eid,ma_data_valid,latched_eid[5:0]};//{mf_frame_valid, sl_data_latch, sl_arb_request, sl_arb_grant, mf_debug[3:0]};//{local_frame_valid, local_data_latch, send_addr, send_eid, send_nak_code, send_ack_code, send_major_ver, send_minor_ver};
wire query_capability_match = new_command && (ma_addr == 8'h3F);
wire set_capability_match = new_command && (ma_addr == 8'h5F);
wire query_request_match = new_command && (ma_addr == 8'h56);
wire ver_request_match = new_command && (ma_addr == 8'h76);
wire query_i2c_match = new_command && (ma_addr == 8'h49);
wire set_i2c_match = new_command && (ma_addr == 8'h69);
wire query_goc_match = new_command && (ma_addr == 8'h4F);
wire set_goc_match = new_command && (ma_addr == 8'h6F);
wire query_gpio_match = new_command && (ma_addr == 8'h47);
wire set_gpio_match = new_command && (ma_addr == 8'h67);
wire query_m3sw_match = new_command && (ma_addr == 8'h53);
wire set_m3sw_match = new_command && (ma_addr == 8'h73);
wire query_mbus_match = new_command && (ma_addr == 8'h4d);
wire set_mbus_match = new_command && (ma_addr == 8'h6d);
wire capability_match = //Each time the feature set changes, it must be reflected here...
	(capability_counter == "?") || 
	(capability_counter == "_") || 
	(capability_counter == "f") || 
	(capability_counter == "O") || 
	(capability_counter == "o") || 
	(capability_counter == "B") || 
	(capability_counter == "b") || 
	(capability_counter == "M") || 
	(capability_counter == "m") || 
	(capability_counter == "P") || 
	(capability_counter == "p");
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
	store_parameter = 1'b0;
	send_parameter = 1'b0;
	shift_parameter = 1'b0;
	store_to_parameter = 1'b0;
	shift_to_parameter = 1'b0;
	latch_temps = 1'b0;
	capability_incr = 1'b0;
	send_capability = 1'b0;

	case(state)
		STATE_IDLE: begin
			latch_command = 1'b1;
			if(generate_nak || query_request_match || ver_request_match || query_i2c_match || set_i2c_match || query_goc_match || set_goc_match || query_gpio_match || set_gpio_match || set_m3sw_match || query_m3sw_match || set_capability_match || query_capability_match || query_mbus_match || set_mbus_match) begin
				next_state = STATE_LATCH_EID;
			end
		end
		
		STATE_LATCH_EID: begin
			latch_eid = ma_data_valid;
			if(ma_data_valid)
				next_state = STATE_SKIP_LENGTH;
		end
		
		STATE_SKIP_LENGTH: begin
			if(ma_data_valid) begin
				if(latched_command[0])
					next_state = STATE_NAK0;
				else if(latched_command[1])
					next_state = STATE_RESP_QUERY0;
				else if(latched_command[2])
					next_state = STATE_RESP_VER0;
				else if(latched_command[3] | latched_command[5] | latched_command[7] | latched_command[9] | latched_command[11] | latched_command[13])
					next_state = STATE_QUERY_PARAM0;
				else if(latched_command[4] | latched_command[6] | latched_command[8] | latched_command[10] | latched_command[12] | latched_command[14])
					next_state = STATE_SET_PARAM0;
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
			if(counter == 8'd1 && ma_data_valid)
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
		
		STATE_QUERY_PARAM0: begin
			store_parameter = 1'b1;
			if(ma_data_valid) begin
				ackgen_generate_ack = 1'b1;
				next_state = STATE_QUERY_PARAM1;
			end
		end
		
		STATE_QUERY_PARAM1: begin
			local_frame_valid = 1'b1;
			if(ack_message_frame_valid == 1'b0)
				//Special case for querying capability
				if(capability_query == 1'b1)
					next_state = STATE_QUERY_CAPABILITY;
				else
					next_state = STATE_QUERY_PARAM2;
		end
		
		STATE_QUERY_PARAM2: begin
			local_frame_valid = 1'b1;
			send_parameter = 1'b1;
			shift_parameter = 1'b1;
			if(parameter_shift_countdown == 1)
				next_state = STATE_IDLE;
		end

		STATE_QUERY_CAPABILITY: begin
			local_frame_valid = 1'b1;
			capability_incr = 1'b1;
			send_capability = capability_match;
			if(capability_counter == 8'hFF)
				next_state = STATE_IDLE;
		end
		
		STATE_SET_PARAM0: begin
			store_to_parameter = 1'b1;
			if(ma_data_valid)
				next_state = STATE_SET_PARAM1;
		end
		
		STATE_SET_PARAM1: begin
			shift_to_parameter = ma_data_valid;
			if(parameter_shift_countdown == 0) begin
				ackgen_generate_ack = 1'b1;
				next_state = STATE_SET_PARAM2;
			end
		end
		
		//Wait for message to stop txing before setting any latched parameters
		STATE_SET_PARAM2: begin
			if(sl_arb_request == 1'b1)//TODO: This could theoretically get tricky if things are backed up
				next_state = STATE_SET_PARAM3;
		end
		
		STATE_SET_PARAM3: begin
			if(sl_arb_request == 1'b0 && uart_tx_empty) begin
				latch_temps = 1'b1;
				next_state = STATE_IDLE;
			end
		end
		
		
	endcase

	//Mux the data out to the message fifo
	local_data = VERSION_MAJOR;
	if(send_minor_ver) local_data = VERSION_MINOR;
	else if(send_parameter) local_data = parameter_staging[23:16];
	else if(send_capability) local_data = capability_counter;
end

reg last_ma_frame_valid;
reg [4:0] to_parameter;
always @(posedge clk) begin
	if(rst) begin
		state <= `SD STATE_IDLE;
		counter <= `SD 8'd0;
		i2c_speed <= `SD 8'd99;
		i2c_addr <= `SD 16'hFFFF;
		`ifdef SIM_FLAG
			goc_speed <= `SD 32'h00000010;
		`else
			goc_speed <= `SD 32'h0061A800;
		`endif
		goc_mode <= `SD 1'b1;
		gpio_direction <= `SD 24'h000000;
		gpio_int_enable <= `SD 24'h000000;
		gpio_level <= `SD 24'h000000;
        // v0.4 - assume 2MBaud
		uart_baud_div <= `SD 16'd10; //20

		{M3_VBATT_SW, M3_1P2_SW, M3_0P6_SW} <= `SD 3'h7;
		mbus_force_reset <= `SD 1'b0;
		mbus_master_mode <= `SD 1'b0;
		mbus_tx_prio <= `SD 1'b0;
		mbus_master_mode <= `SD 1'b0;
		mbus_snoop_enabled <= `SD 1'b0;
		mbus_long_addr <= `SD 20'hfffff;
		mbus_short_addr_override <= `SD 4'hf;
		mbus_clk_div <= `SD 22'h000020;
	end else begin
		state <= `SD next_state;
		if(capability_incr) begin
			capability_counter <= `SD capability_counter + 1;
		end else begin
			capability_counter <= `SD 0;
		end

		//Parameter setting/querying logic
		if(store_parameter) begin
			capability_query <= 1'b0;
			if(latched_command[3]) begin //I2C parameter query
				if(ma_data == 8'h63) begin
					parameter_staging <= `SD {i2c_speed,16'h0000};
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == 8'h61) begin
					parameter_staging <= `SD {i2c_addr,8'h00};
					parameter_shift_countdown <= `SD 2;
				end
			end else if(latched_command[5]) begin //GOC parameter query
				if(ma_data == 8'h6f) begin
					parameter_staging <= `SD {goc_polarity, 16'h0000};
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == 8'h70) begin
					parameter_staging <= `SD {goc_mode, 16'h0000};
					parameter_shift_countdown <= `SD 1;
				end else begin
					parameter_staging <= `SD goc_speed;
					parameter_shift_countdown <= `SD 4;
				end
			end else if(latched_command[7]) begin
				if(ma_data == 8'h6c) begin
					parameter_staging <= `SD gpio_read;
					parameter_shift_countdown <= `SD 3;
				end else if(ma_data == 8'h64) begin
					parameter_staging <= `SD gpio_direction;
					parameter_shift_countdown <= `SD 3;
				end else if(ma_data == 8'h69) begin
					parameter_staging <= `SD gpio_int_enable;
					parameter_shift_countdown <= `SD 3;
				end
			end else if(latched_command[9]) begin
				parameter_staging <= `SD {M3_VBATT_SW, M3_1P2_SW, M3_0P6_SW, 21'h000000};
				parameter_shift_countdown <= `SD 1;
			end else if(latched_command[11]) begin
				if(ma_data == 8'h62) begin
					parameter_staging <= `SD {uart_baud_div,8'h00};
					parameter_shift_countdown <= `SD 2;
				end else if(ma_data == 8'h3F) begin
					capability_query <= `SD 1'b1;
				end
			end else if(latched_command[13]) begin
				if(ma_data == "m") begin
					parameter_staging <= `SD {mbus_master_mode, 16'h0000};
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "p") begin
					parameter_staging <= `SD {mbus_tx_prio, 16'h0000};
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "l") begin
					parameter_staging <= `SD {4'b0000, mbus_long_addr};
					parameter_shift_countdown <= `SD 3;
				end else if(ma_data == "r") begin
					parameter_staging <= `SD {7'b0000000, mbus_force_reset, 16'h0000};
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "s") begin
					parameter_staging <= `SD {4'b000, mbus_short_addr_override, 16'h0000};
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "S") begin
					parameter_staging <= `SD {7'b0000000, mbus_snoop_enabled, 16'h0000};
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "c") begin
					parameter_staging <= `SD mbus_clk_div;
					parameter_shift_countdown <= `SD 3;
				end
			end
		end
		if(shift_parameter) begin
			parameter_shift_countdown <= `SD parameter_shift_countdown - 1;
			parameter_staging <= `SD {parameter_staging[15:0], 8'h00};
		end
		if(store_to_parameter) begin
			if(latched_command[4]) begin //I2C parameter setting
				if(ma_data == 8'h63) begin
					to_parameter <= `SD 0;
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == 8'h61) begin
					to_parameter <= `SD 1;
					parameter_shift_countdown <= `SD 2;
				end
			end else if(latched_command[6]) begin //GOC parameter setting
				if(ma_data == 8'h6f) begin
					to_parameter <= `SD 6;
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == 8'h70) begin
					to_parameter <= `SD 11;
					parameter_shift_countdown <= `SD 1;
				end else begin
					to_parameter <= `SD 2;
					parameter_shift_countdown <= `SD 4;
				end
			end else if(latched_command[8]) begin //GPIO parameter setting
				if(ma_data == 8'h6c) 
					to_parameter <= `SD 3;
				else if(ma_data== 8'h64)
					to_parameter <= `SD 4;
				else if(ma_data == 8'h69)
					to_parameter <= `SD 12;
				parameter_shift_countdown <= `SD 3;
			end else if(latched_command[10]) begin
				to_parameter <= `SD 5;
				parameter_shift_countdown <= `SD 1;
			end else if(latched_command[12]) begin
				to_parameter <= `SD 7;
				parameter_shift_countdown <= `SD 2;
			end else if(latched_command[14]) begin
				if(ma_data == "l") begin
					to_parameter <= `SD 8;
					parameter_shift_countdown <= `SD 3;
				end else if(ma_data == "r") begin
					to_parameter <= `SD 16;
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "s") begin
					to_parameter <= `SD 14;
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "S") begin
					to_parameter <= `SD 15;
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "p") begin
					to_parameter <= `SD 13;
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "m") begin
					to_parameter <= `SD 9;
					parameter_shift_countdown <= `SD 1;
				end else if(ma_data == "c") begin
					to_parameter <= `SD 10;
					parameter_shift_countdown <= `SD 3;
				end
			end
		end
		if(shift_to_parameter) begin
			if(to_parameter == 0)
				i2c_speed <= `SD ma_data;
			else if(to_parameter == 1)
				i2c_addr <= `SD {i2c_addr[7:0], ma_data};
			else if(to_parameter == 2)
				goc_speed <= `SD {goc_speed[23:0], ma_data};
			else if(to_parameter == 3)
				gpio_level_temp <= `SD {gpio_level_temp[15:0], ma_data};
			else if(to_parameter == 4)
				gpio_direction_temp <= `SD {gpio_direction_temp[15:0], ma_data};
			else if(to_parameter == 5)
				{M3_VBATT_SW, M3_1P2_SW, M3_0P6_SW} <= `SD ma_data[2:0];
			else if(to_parameter == 6)
				goc_polarity <= `SD ma_data[0];
			else if(to_parameter == 7)
				uart_baud_temp <= `SD {uart_baud_temp[7:0], ma_data};
			else if(to_parameter == 8)
				mbus_long_addr <= `SD {mbus_long_addr[11:0], ma_data};
			else if(to_parameter == 9)
				mbus_master_mode <= `SD ma_data[0];
			else if(to_parameter == 10)
				mbus_clk_div <= `SD {mbus_clk_div[13:0], ma_data};
			else if(to_parameter == 11)
				goc_mode <= `SD ma_data[0];
			else if(to_parameter == 12)
				gpio_int_enable_temp <= `SD {gpio_int_enable_temp[15:0], ma_data};
			else if(to_parameter == 13)
				mbus_tx_prio <= `SD ma_data[0];
			else if(to_parameter == 14)
				mbus_short_addr_override <= `SD ma_data[3:0];
			else if(to_parameter == 15)
				mbus_snoop_enabled <= `SD ma_data[0];
			else if(to_parameter == 16)
				mbus_force_reset <= `SD ma_data[0];
				
			parameter_shift_countdown <= `SD parameter_shift_countdown - 1;
		end
		if(latch_temps) begin
			if(to_parameter == 3)
				gpio_level <= `SD gpio_level_temp;
			else if(to_parameter == 4)
				gpio_direction <= `SD gpio_direction_temp;
			else if(to_parameter == 7)
				uart_baud_div <= `SD uart_baud_temp;
			else if(to_parameter == 12)
				gpio_int_enable <= `SD gpio_int_enable_temp;
		end

		last_ma_frame_valid <= `SD ma_frame_valid;
		if(ma_frame_valid && ~last_ma_frame_valid) begin
			ma_addr <= `SD ma_data;
			new_command <= `SD 1'b1;
		end else if(ma_data_valid) begin
			new_command <= `SD 1'b0;
		end

		if(latch_eid)
			latched_eid <= `SD ma_data;
		
		if(next_state != state)
			counter <= `SD 0;
		else if(data_counter_incr)
			counter <= `SD counter + 1;

		if(shift_ver_in)
			version_in <= `SD {version_in[7:0], ma_data};

		if(latch_command) begin
			latched_command <= `SD {set_mbus_match, query_mbus_match, set_capability_match, query_capability_match, set_m3sw_match, query_m3sw_match, set_gpio_match, query_gpio_match, set_goc_match, query_goc_match, set_i2c_match, query_i2c_match, ver_request_match, query_request_match, generate_nak};
			//                      14              13                12                    11                      10              9                 8               7                 6              5                4              3                2                  1                    0
		end

	end
end

endmodule
