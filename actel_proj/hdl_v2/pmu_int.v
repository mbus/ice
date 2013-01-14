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
	inout [7:0] sl_data,
	output sl_arb_request,
	input sl_arb_grant,
	input sl_data_latch
);

wire [7:0] in_char;
wire [7:0] ack_message_data;
wire ack_message_data_valid;
wire ack_message_frame_valid;

wire hd_data_valid, hd_frame_valid, hd_data_latch, hd_header_done;
wire [7:0] hd_header_eid;
bus_interface #(8'h70,0,1,0) bi0(
	.clk(clk),
	.rst(reset),
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),
	.sl_data(sl_data),
	.sl_arb_request(sl_arb_request),
	.sl_arb_grant(sl_arb_grant),
	.sl_data_latch(sl_data_latch),
	.in_frame_data(in_char),
	.in_frame_data_valid(hd_data_valid),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_latch(hd_data_latch),
	.out_frame_data(ack_message_data),
	.out_frame_valid(ack_message_frame_valid),
	.out_frame_data_latch(ack_message_data_valid)
);
header_decoder hd0(
	.clk(clk),
	.rst(reset),
	.in_frame_data(in_char),
	.in_frame_data_valid(hd_data_valid),
	.in_frame_valid(hd_frame_valid),
	.header_eid(hd_header_eid),
	.frame_data_latch(hd_data_latch),
	.header_done(hd_header_done),
	.header_done_clear(1'b0)
);

/*bus_interface #(8'h50,0,0,0) bi1(
	.clk(clk),
	.rst(reset),
	.ma_data(ma_data),
	.ma_addr(ma_addr),
	.ma_data_valid(ma_data_valid),
	.ma_frame_valid(ma_frame_valid),
	.sl_overflow(sl_overflow),
	.in_frame_data(in_char),
	.in_frame_data_valid(hd_data_valid),
	.in_frame_valid(hd_frame_valid),
	.in_frame_data_latch(hd_data_latch)
);*/

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
	
	.message_data(ack_message_data),
	.message_data_valid(ack_message_data_valid),
	.message_frame_valid(ack_message_frame_valid)
);

reg latch_param, latch_idx, latch_val;
reg pmu_start, pmu_done, pmu_clear_failed, pmu_param;
reg drive_pmu_addr, drive_pmu_subaddr, drive_pmu_val;
reg [3:0] pwr_idx;
reg [2:0] pmu_en_reg, pmu_dac_val;

wire pmu_data_latch, pmu_ready, pmu_failed;
wire [7:0] pmu_subaddr = (pmu_param == 1'b0) ? 8'h10 :
                         (pwr_idx == 0) ? 8'h32 :
						 (pwr_idx == 1) ? 8'h26 : 8'h29;
wire [7:0] pmu_val = (pmu_param == 1'b0) ? {3'b100,pmu_en_reg[0],1'b1,pmu_en_reg[2:1],1'b1} : pmu_dac_val;

reg [3:0] state, next_state;
parameter STATE_IDLE = 0;
parameter STATE_GET_PARAM = 1;
parameter STATE_GET_IDX = 2;
parameter STATE_GET_VAL = 3;
parameter STATE_I2C_ADDR = 4;
parameter STATE_I2C_SUBADDR = 5;
parameter STATE_I2C_DATA = 6;
parameter STATE_ACK = 7;

pmu_i2c pi0(
	.clk(clk),
	.reset(reset),
	
	.scl(pmu_scl),
	.sda(pmu_sda),
	
	.data((drive_pmu_addr) ? 8'h68 : (drive_pmu_subaddr) ? pmu_subaddr : pmu_val),
	.start(pmu_start),
	.done(pmu_done),
	.data_latch(pmu_data_latch),
	
	.ready(pmu_ready),
	.failed(pmu_failed),
	.clear_failed(pmu_clear_failed)
);

always @(posedge clk) begin
	if(reset) begin
		state <= STATE_IDLE;
		pmu_en_reg <= 8'b10001001;
	end else begin
		state <= next_state;
		
		//Figure out whether we want to set voltage or on/off
		if(latch_param)
			pmu_param <= (in_char == 8'h76) ? 1'b1 : 1'b0;
			
		//Latch the identifier for whilch power rail we are talking about
		if(latch_idx)
			pwr_idx <= in_char[3:0];
		
		//Latch the input argument, modifying the default enable register if that's the destination
		if(latch_val) begin
			if(pmu_param)
				pmu_dac_val <= in_char;
			else
				if(pwr_idx == 0)
					pmu_en_reg <= {pmu_en_reg[2:1],in_char[0]};
				else if(pwr_idx == 1)
					pmu_en_reg <= {pmu_en_reg[2],in_char[0],pmu_en_reg[0]};
				else if(pwr_idx == 2)
					pmu_en_reg <= {in_char[0],pmu_en_reg[1:0]};
		end
	end
end

always @* begin
	next_state = state;
	latch_param = 1'b0;
	latch_idx = 1'b0;
	latch_val = 1'b0;
	pmu_start = 1'b0;
	pmu_done = 1'b0;
	pmu_clear_failed = 1'b0;
	drive_pmu_addr = 1'b0;
	drive_pmu_subaddr = 1'b0;
	drive_pmu_val = 1'b0;
	pmu_clear_failed = 1'b0;
	ackgen_generate_ack = 1'b0;
	ackgen_generate_nak = 1'b0;
	
	case(state)
		STATE_IDLE: begin
			if(hd_header_done)
				next_state = STATE_GET_PARAM;
		end
		
		STATE_GET_PARAM: begin
			latch_param = 1'b1;
			if(hd_data_valid)
				next_state = STATE_GET_IDX;
		end
		
		STATE_GET_IDX: begin
			latch_idx = 1'b1;
			if(hd_data_valid)
				next_state = STATE_GET_VAL;
		end
		
		STATE_GET_VAL: begin
			latch_val = 1'b1;
			if(hd_data_valid)
				next_state = STATE_I2C_ADDR;
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
			pmu_done = 1'b1;
			if(pmu_ready)
				next_state = STATE_ACK;
		end
		
		STATE_ACK: begin
			pmu_clear_failed = 1'b1;
			ackgen_generate_ack = ~pmu_failed;
			ackgen_generate_nak = pmu_failed;
			next_state = STATE_IDLE;
		end
	endcase
end

endmodule
