`include "include/ice_def.v"

module pmu_int(
	input clk,
	input reset,
	
	inout pmu_scl,
	inout pmu_sda,
	
	//Master input bus
	input [7:0] ma_data,
	input [7:0] ma_addr,
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
	
	output [7:0] debug
);

wire [8:0] in_char;
wire [7:0] ack_message_data;
wire ack_message_data_valid;
wire ack_message_frame_valid;
reg insert_frame_valid, insert_data_valid;
wire [7:0] insert_data;

reg latch_param, latch_rd_param, latch_idx, latch_rd_idx, latch_val;
reg hd_header_done_clear;

wire hd_frame_valid, hd_frame_data_valid, hd_header_done;
wire [8:0] hd_frame_tail, hd_frame_addr;
wire hd_frame_latch_tail;
wire [7:0] hd_header_eid;
bus_interface #(
.ADDR(8'h70),
.INCLUDE_INPUT_FIFO(0),
.INCLUDE_OUTPUT_FIFO(1),
.SUPPORTS_FRAGMENTATION(0),
.OUTPUT_FIFO_DEPTH_LOG2(4)
) bi0(
	.clk(clk),
	.rst(reset),
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),
	.sl_addr(sl_addr),
	.sl_tail(sl_tail),
	.sl_latch_tail(sl_latch_tail),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request),
	.sl_arb_grant(sl_arb_grant),
	.in_frame_data(in_char),
	.in_frame_valid(hd_frame_valid),
	.in_frame_tail(hd_frame_tail),
	.in_frame_addr(hd_frame_addr),
	.in_frame_latch_tail(hd_frame_latch_tail),
	.in_frame_data_valid(hd_frame_data_valid),
	.out_frame_data((insert_data_valid) ? insert_data : ack_message_data),
	.out_frame_valid(ack_message_frame_valid | insert_frame_valid),
	.out_frame_data_latch(ack_message_data_valid | insert_data_valid)
);
header_decoder hd0(
	.clk(clk),
	.rst(reset),
	.in_frame_data(in_char),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_valid(hd_frame_data_valid),
	.in_frame_tail(hd_frame_tail),
	.in_frame_next(latch_param | latch_idx | latch_val),
	.in_frame_addr(hd_frame_addr),
	.in_frame_latch_tail(hd_frame_latch_tail),
	.header_eid(hd_header_eid),
	.header_done(hd_header_done),
	.header_done_clear(hd_header_done_clear)
);


//This bus interface is used to monitor for query requests
wire hd2_frame_valid, hd2_frame_latch_tail, hd2_frame_data_valid;
wire [8:0] in_query_char, hd2_frame_tail, hd2_frame_addr;
wire [7:0] hd2_header_eid;
bus_interface #(8'h50,0,0,0) bi1(
	.clk(clk),
	.rst(reset),
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
    .sl_addr(9'h0),
	.sl_arb_grant(1'h0),
    .in_frame_tail(hd2_frame_tail),
	.in_frame_addr(hd2_frame_addr),
	.in_frame_latch_tail(hd2_frame_latch_tail),
	.in_frame_data(in_query_char),
	.in_frame_data_valid(hd2_frame_data_valid),
	.in_frame_valid(hd2_frame_valid)
);

header_decoder hd1(
	.clk(clk),
	.rst(reset),
	.in_frame_data(in_query_char),
	.in_frame_valid(hd2_frame_valid),
	.in_frame_data_valid(hd2_frame_data_valid),
	.in_frame_tail(hd2_frame_tail),
	.in_frame_next(latch_rd_param | latch_rd_idx),
	.in_frame_addr(hd2_frame_addr),
	.in_frame_latch_tail(hd2_frame_latch_tail),
	.header_eid(hd2_header_eid),
	.header_done(hd2_header_done),
	.header_done_clear(hd_header_done_clear)
);

/************************************************************
 *Ack generator is used to easily create ACK & NAK sequences*
 ************************************************************/
reg ackgen_generate_ack, ackgen_generate_nak;
ack_generator ag0(
	.clk(clk),
	.reset(reset),
	
	.generate_ack(ackgen_generate_ack),
	.generate_nak(ackgen_generate_nak),
	.eid_in(hd_header_eid),
	
    .message_wait(1'h0),
	.message_data(ack_message_data),
	.message_data_valid(ack_message_data_valid),
	.message_frame_valid(ack_message_frame_valid)
);

reg pmu_start, pmu_done, pmu_clear_failed, pmu_param;
reg drive_pmu_addr, drive_pmu_subaddr, drive_pmu_val, drive_pmu_addr_rd;
reg first_time, incr_first_time;
reg set_slew, slew;
reg [3:0] pwr_idx;
reg [3:0] pmu_en_reg;
reg [4:0] pmu_dac_val;

wire pmu_data_latch, pmu_ready, pmu_failed;
wire [7:0] pmu_subaddr = (slew) ? 8'h20 : 
                         (pmu_param == 1'b0) ? 8'h10 :
                         (pwr_idx == 0) ? 8'h32 :
						 (pwr_idx == 1) ? 8'h26 : 
						 (pwr_idx == 2) ? 8'h29 : 8'h23;
wire [7:0] pmu_val =     (slew) ? 8'h55 :
                         (pmu_param == 1'b0) ? {3'b100,pmu_en_reg[0],1'b1,pmu_en_reg[2:1],pmu_en_reg[3]} : {3'd0, pmu_dac_val};

reg i2c_rw;
wire [7:0] in_i2c_data;
wire in_i2c_data_valid;

reg [4:0] state, next_state;
parameter STATE_IDLE = 0;
parameter STATE_GET_PARAM = 1;
parameter STATE_GET_IDX = 2;
parameter STATE_GET_VAL = 3;
parameter STATE_I2C_ADDR = 4;
parameter STATE_I2C_SUBADDR = 5;
parameter STATE_I2C_DATA = 6;
parameter STATE_I2C_DONE = 7;
parameter STATE_START_SLEW = 8;
parameter STATE_ACK = 9;
parameter STATE_RD_GET_PARAM = 10;
parameter STATE_RD_GET_IDX = 11;
parameter STATE_RD_I2C_ADDR = 12;
parameter STATE_RD_I2C_SUBADDR = 13;
parameter STATE_RD_I2C_DATA = 14;
parameter STATE_RD_I2C_DONE = 15;
parameter STATE_RD_VALIDATE = 16;
parameter STATE_RD_VALIDATE2 = 17;
parameter STATE_RD_VALIDATE3 = 18;

assign debug = {3'd0,state};

pmu_i2c pi0(
	.clk(clk),
	.reset(reset),
	
	.scl(pmu_scl),
	.sda(pmu_sda),
	
	.data((drive_pmu_addr) ? 8'h68 : (drive_pmu_addr_rd) ? 8'h69 : (drive_pmu_subaddr) ? pmu_subaddr : pmu_val),
	.start(pmu_start),
	.done(pmu_done),
	.rw(i2c_rw),
	.data_latch(pmu_data_latch),
	
	.ready(pmu_ready),
	.failed(pmu_failed),
	.in_data(in_i2c_data),
	.in_data_valid(in_i2c_data_valid),
	.clear_failed(pmu_clear_failed)
);

always @(posedge clk) begin
	if(reset) begin
		state <= `SD STATE_IDLE;
		pmu_en_reg <= `SD 0;
		first_time <= `SD 1;
	end else begin
		state <= `SD next_state;
		
		//Figure out whether we want to set voltage or on/off
		if(latch_param)
			pmu_param <= `SD (in_char == 8'h76) ? 1'b1 : 1'b0;
		if(latch_rd_param)
			pmu_param <= `SD (in_query_char[7:0] == 8'h76) ? 1'b1 : 1'b0;
			
		//Latch the identifier for whilch power rail we are talking about
		if(latch_idx)
			pwr_idx <= `SD in_char[3:0];
		if(latch_rd_idx)
			pwr_idx <= `SD in_query_char[3:0];
		
		//Latch the input argument, modifying the default enable register if that's the destination
		if(latch_val) begin
			if(pmu_param)
				pmu_dac_val <= `SD in_char[4:0];
			else
				if(pwr_idx == 0)
					pmu_en_reg <= `SD {pmu_en_reg[3:1],in_char[0]};
				else if(pwr_idx == 1)
					pmu_en_reg <= `SD {pmu_en_reg[3:2],in_char[0],pmu_en_reg[0]};
				else if(pwr_idx == 2)
					pmu_en_reg <= `SD {pmu_en_reg[3],in_char[0],pmu_en_reg[1:0]};
				else if(pwr_idx == 3)
					pmu_en_reg <= `SD {in_char[0],pmu_en_reg[2:0]};
		end
		
		//We need to do two different I2C transactions if slewing
		if(set_slew) begin
			slew <= `SD 1'b1;
		end else if(latch_param)
			slew <= `SD 1'b0;
		
		if(incr_first_time)
			first_time <= `SD ~first_time;
	end
end

assign insert_data = (pmu_param) ? in_i2c_data :
                     (pwr_idx == 0) ? in_i2c_data[4] :
					 (pwr_idx == 1) ? in_i2c_data[1] : 
					 (pwr_idx == 2) ? in_i2c_data[2] : in_i2c_data[0];

always @* begin
	next_state = state;
	latch_param = 1'b0;
	latch_idx = 1'b0;
	latch_val = 1'b0;
	pmu_start = 1'b0;
	pmu_done = 1'b0;
	pmu_clear_failed = 1'b0;
	drive_pmu_addr = 1'b0;
	drive_pmu_addr_rd = 1'b0;
	drive_pmu_subaddr = 1'b0;
	drive_pmu_val = 1'b0;
	pmu_clear_failed = 1'b0;
	ackgen_generate_ack = 1'b0;
	ackgen_generate_nak = 1'b0;
	i2c_rw = 1'b1;
	latch_rd_param = 1'b0;
	latch_rd_idx = 1'b0;
	incr_first_time = 1'b0;
	insert_frame_valid = 1'b0;
	insert_data_valid = 1'b0;
	set_slew = 1'b0;
	hd_header_done_clear = 1'b0;
	
	case(state)
		STATE_IDLE: begin
			hd_header_done_clear = 1'b1;
			if(hd_header_done)
				next_state = STATE_GET_PARAM;
			else if(hd2_header_done)
				next_state = STATE_RD_GET_PARAM;
		end
		
		STATE_GET_PARAM: begin
			if(ma_data_valid) begin
				latch_param = 1'b1;
				next_state = STATE_GET_IDX;
			end
		end
		
		STATE_GET_IDX: begin
			if(ma_data_valid) begin
				latch_idx = 1'b1;
				next_state = STATE_GET_VAL;
			end
		end
		
		STATE_GET_VAL: begin
			if(ma_data_valid) begin
				latch_val = 1'b1;
				next_state = STATE_I2C_ADDR;
			end
		end
		
		STATE_I2C_ADDR: begin
			drive_pmu_addr = 1'b1;
			pmu_start = 1'b1;
			if(pmu_data_latch)
				next_state = STATE_I2C_SUBADDR;
		end
		
		STATE_I2C_SUBADDR: begin
			drive_pmu_subaddr = 1'b1;
			if(pmu_data_latch)
				next_state = STATE_I2C_DATA;
		end
		
		STATE_I2C_DATA: begin
			drive_pmu_val = 1'b1;
			if(pmu_data_latch)
				next_state = STATE_I2C_DONE;
		end
		
		STATE_I2C_DONE: begin
			pmu_done = 1'b1;
			if(pmu_ready)
				if(slew)
					next_state = STATE_ACK;
				else
					next_state = STATE_START_SLEW;
		end
		
		STATE_START_SLEW: begin
			set_slew = 1'b1;
			next_state = STATE_I2C_ADDR;
		end
		
		STATE_ACK: begin
			pmu_clear_failed = 1'b1;
			ackgen_generate_ack = ~pmu_failed;
			ackgen_generate_nak = pmu_failed;
			next_state = STATE_IDLE;
		end
		
		//All the query states are pretty much the same.  
		//But different enough that I just created new states 
		//instead of dealing with combining the two
		STATE_RD_GET_PARAM: begin
			latch_rd_param = 1'b1;
			next_state = STATE_RD_GET_IDX;
		end
		
		STATE_RD_GET_IDX: begin
			latch_rd_idx = 1'b1;
			next_state = STATE_RD_I2C_ADDR;
		end
		
		STATE_RD_I2C_ADDR: begin
			drive_pmu_addr = first_time;
			drive_pmu_addr_rd = ~first_time;
			pmu_start = 1'b1;
			if(pmu_data_latch)
				if(first_time)
					next_state = STATE_RD_I2C_SUBADDR;
				else
					next_state = STATE_RD_I2C_DATA;
		end
		
		STATE_RD_I2C_SUBADDR: begin
			drive_pmu_subaddr = 1'b1;
			if(pmu_data_latch)
				next_state = STATE_RD_I2C_DATA;
		end
		
		STATE_RD_I2C_DATA: begin
			i2c_rw = 1'b0;
			if(pmu_data_latch)
				next_state = STATE_RD_I2C_DONE;
		end
		
		STATE_RD_I2C_DONE: begin
			pmu_done = 1'b1;
			if(pmu_ready) begin
				incr_first_time = 1'b1;
				if(first_time)
					next_state = STATE_RD_I2C_ADDR;
				else
					next_state = STATE_RD_VALIDATE;
			end
		end
		
		STATE_RD_VALIDATE: begin
			ackgen_generate_ack = ~pmu_failed;
			next_state = STATE_RD_VALIDATE2;
		end
		
		STATE_RD_VALIDATE2: begin
			insert_frame_valid = 1'b1;
			if(ack_message_frame_valid)
				next_state = STATE_RD_VALIDATE3;
		end
		
		STATE_RD_VALIDATE3: begin
			insert_frame_valid = 1'b1;
			insert_data_valid = 1'b1;
			next_state = STATE_IDLE;
		end
	endcase
end

endmodule
