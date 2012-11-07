module fuck_libero(
	input clock,
	input reset,

	input suppress_outputs,
	input freeze_ack,

	input SCL_m_in,
	inout SCL_c_inout,

	input SDA_m_in,
	inout SDA_c_inout,

	output reg SDA_c_pull_mid,

	output reg SCL_mpd,
	output reg SCL_mpu,
	output SCL_mp,

	output reg SDA_mpd,
	output reg SDA_mpu,
	output SDA_mp,

	output [7:0] leds
);

///////////////////////////
// Declare signal inputs //

reg SCL_m;
reg SCL_c;

reg SDA_m;
reg SDA_c;

`define TICK_WIDTH 8

reg [3:0] state;
reg [3:0] next_state;

`define STATE_NONE               4'd0
`define STATE_START              4'd1
`define STATE_BITS0_7_SCL_LOW    4'd2
`define STATE_BITS0_7_SCL_HIGH   4'd3
`define STATE_ACK_SCL_LOW        4'd4
`define STATE_ACK_SCL_HIGH       4'd5
`define STATE_STOP               4'd6

reg [1:0] master;
reg [1:0] next_master;

`define MASTER_NONE	             2'b00
`define MASTER_M                 2'b01
`define MASTER_C                 2'b10

wire master_scl;
wire master_sda;
wire slave_sda;

reg last_master_sda;

assign master_scl = (master == `MASTER_M) ? SCL_m : (master == `MASTER_C) ? SCL_c : 1'b1;
assign master_sda = (master == `MASTER_M) ? SDA_m : (master == `MASTER_C) ? SDA_c : 1'b1;
assign  slave_sda = (master == `MASTER_M) ? SDA_c : (master == `MASTER_C) ? SDA_m : 1'b1;

reg [3:0] bit_count;
reg [3:0] next_bit_count;

reg [`TICK_WIDTH-1:0] pulse_count;
reg [`TICK_WIDTH-1:0] next_pulse_count;

//New safer signals
reg slave_scl_drive;
reg slave_sda_drive;
reg slave_scl_value;
reg slave_sda_value;
reg master_sda_drive;
reg master_sda_value;

reg next_slave_scl_drive;
reg next_slave_sda_drive;
reg next_slave_scl_value;
reg next_slave_sda_value;
reg next_master_sda_drive;
reg next_master_sda_value;

reg c_pull_mid;
reg next_c_pull_mid;

always @*
begin
	next_master = master;
	next_state = state;
	next_bit_count = bit_count;
	next_pulse_count = pulse_count;

	next_slave_scl_drive = slave_scl_drive;
	next_slave_sda_drive = slave_sda_drive;
	next_slave_scl_value = slave_scl_value;
	next_slave_sda_value = slave_sda_value;
	
	next_master_sda_drive = master_scl_drive;
	next_master_sda_value = master_sda_value;

	// Always 0 except a few specific cases
	next_c_pull_mid = 0;

	case(state)
		`STATE_NONE:
			begin
				next_bit_count = 0;
				next_pulse_count = 0;
				next_slave_scl_drive = 0;
				next_slave_sda_drive = 0;

				if (SDA_m == 1'b0) begin
					next_master = `MASTER_M;
					next_state = `STATE_START;
				end else if (SDA_c == 1'b0) begin
					next_master = `MASTER_C;
					next_state = `STATE_START;
				end
			end

		`STATE_START:
			begin
				next_slave_sda_drive = 1'b1;
				next_slave_sda_value = 1'b0;

				if (master_sda == 1'b1 && master_scl == 1'b1)
					next_state = `STATE_STOP;
				else if (master_sda == 1'b0 && master_scl == 1'b0)
					next_state = `STATE_BITS0_7_SCL_LOW;
			end

		`STATE_BITS0_7_SCL_LOW:
			begin
				next_slave_sda_drive = 1'b1;
				next_slave_scl_drive = 1'b1;
				next_slave_scl_value = 1'b0;

				if (pulse_count > 0)
					next_slave_sda_value = master_sda;

				if (pulse_count > 9) begin
					// Data is stable after 1000ns
					next_c_pull_mid = 1'b0;
				end else begin
					next_pulse_count = pulse_count + `TICK_WIDTH'd1;
					next_c_pull_mid = 1'b1;
				end

				if (master_scl == 1'b1) begin
					next_bit_count = bit_count + 4'b1;
					next_state = `STATE_BITS0_7_SCL_HIGH;
				end
			end

		`STATE_BITS0_7_SCL_HIGH:
			begin
				next_slave_scl_drive = 1'b1;
				next_slave_scl_value = 1'b1;

				next_pulse_count = 0;

				if (master_scl == 1'b0) begin
					if (bit_count == 4'd8) begin
						next_bit_count = 0;
						next_state = `STATE_ACK_SCL_LOW;
					end else begin
						next_state = `STATE_BITS0_7_SCL_LOW;
					end
				end else begin
					if(master_sda == 1'b1 && last_master_sda == 1'b0) begin
						next_state = `STATE_STOP;
					end
				end
			end

		`STATE_ACK_SCL_LOW:
			begin
				next_slave_scl_drive = 1'b1;
				next_slave_scl_value = 1'b0;

				next_master_sda_drive = 1'b1;
				next_master_sda_value = slave_sda;

				next_pulse_count = pulse_count + `TICK_WIDTH'b1;
				
				if (pulse_count == `TICK_WIDTH'd35) begin
					next_pulse_count = pulse_count;
				end else if (pulse_count == `TICK_WIDTH'd34) begin
					next_slave_sda_drive = 1'b1;
					next_slave_sda_value = slave_sda;
				end else if (pulse_count >= `TICK_WIDTH'd9) begin
					next_slave_sda_drive = 1'b0;
					next_c_pull_mid = 1'b0;	
				end else begin
					next_c_pull_mid = 1'b1;
					if (pulse_count > `TICK_WIDTH'd4) begin
						next_slave_sda_drive = 1'b1;
						next_slave_sda_value = 1'b1;
					end
				end

				if (master_scl == 1'b1) begin
					if (! freeze_ack) begin
						next_pulse_count = 0;
						next_state = `STATE_ACK_SCL_HIGH;
					end
				end
			end

		`STATE_ACK_SCL_HIGH:
			begin
				next_slave_scl_drive = 1'b1;
				next_slave_scl_value = 1'b1;

				if (master_scl == 1'b0) begin
					next_pulse_count = pulse_count + `TICK_WIDTH'b1;

					next_slave_scl_value = 1'b0;

					if (pulse_count > `TICK_WIDTH'd8) begin
						next_state = `STATE_BITS0_7_SCL_LOW;
						next_pulse_count = 0;

						next_master_sda_drive = 1'b0;
					end
				end
			end

		`STATE_STOP:
			begin
				// Not actively driving while the other line swings can cause a glitch, so 
				// we continue to drive clock high here for a few cycles while data transitions
				next_slave_scl_drive = 1'b1;
				next_slave_scl_value = 1'b1;
				
				next_slave_sda_drive = 1'b1;
				next_slave_sda_value = 1'b1;

				next_pulse_count = pulse_count + `TICK_WIDTH'b1;

				if (pulse_count > `TICK_WIDTH'd24) begin
					next_slave_sda_drive = 1'b0;
					next_slave_scl_drive = 1'b0;
				end else if (pulse_count > `TICK_WIDTH'd12) begin
						// it's been long enough now to release the clock line
						next_slave_scl_drive = 1'b0;
					end
				end
				
				if (pulse_count == `TICK_WIDTH'd48)
					next_state = `STATE_NONE;
			end
	endcase
end

// DEGLITCHING LOGIC
reg [`TICK_WIDTH-1:0] scl_limiter;
reg [`TICK_WIDTH-1:0] next_scl_limiter;
`define SCL_LIMIT (`TICK_WIDTH'd20)

wire limit_scl;
assign limit_scl = (master == `MASTER_M) ? 1'b0 : (scl_limiter < (`SCL_LIMIT));

always @*
begin
	if (scl_limiter < (`SCL_LIMIT)) begin
		next_scl_limiter = scl_limiter + `TICK_WIDTH'd1;
	end else begin
		next_scl_limiter = scl_limiter;
	end

	if (master == `MASTER_M) begin
		next_scl_limiter = 0;
	end

	if (!limit_scl && (master == `MASTER_C)) begin
		if (master_scl != SCL_c_inout) begin
			next_scl_limiter = 0;
		end
	end
end


// Actually latch inputs
always @(posedge clock) begin
	if (reset) begin
		SCL_m <= 1'b1;
		SCL_c <= 1'b1;
		SDA_m <= 1'b1;
		SDA_c <= 1'b1;

		scl_limiter <= 0;
	end else begin
		if (! ((limit_scl) && (master == `MASTER_M)) ) begin
			SCL_m <= SCL_m_in;
		end
		if (! ((limit_scl) && (master == `MASTER_C)) ) begin
			SCL_c <= SCL_c_inout;
		end
		SDA_m <= SDA_m_in;
		SDA_c <= SDA_c_inout;

		scl_limiter <= next_scl_limiter;
	end
end


always @(posedge clock)
begin
	last_master_sda <= master_sda;
	master <= next_master;
	bit_count <= next_bit_count;
	pulse_count <= next_pulse_count;	
	c_pull_mid <= next_c_pull_mid;	
	
	slave_scl_drive <= next_slave_scl_drive;
	slave_sda_drive <= next_slave_sda_drive;
	master_sda_drive <= next_master_sda_drive;
	
	slave_scl_value <= next_slave_scl_value;
	slave_sda_value <= next_slave_sda_value;
	master_sda_value <= next_master_sda_value;
	
	if (reset) begin
		state <= `STATE_NONE;
	end else begin
		state <= next_state;
	end
end


reg SCL_cpd;
reg SDA_cpd;

always @*
begin
	SCL_mpd = 1'b0;
	SCL_mpu = 1'b0;
	SCL_cpd = 1'b0;

	SDA_mpd = 1'b0;
	SDA_mpu = 1'b0;
	SDA_cpd = 1'b0;

	SDA_c_pull_mid = 1'bz;

	if (!suppress_outputs) begin
		if (master == `MASTER_M) begin
			SCL_mpd = 1'b0;
			SCL_mpu = 1'b0;
			SCL_cpd = slave_scl_pd;

			SDA_mpd = master_sda_pd;
			SDA_mpu = master_sda_pu;
			SDA_cpd = slave_sda_pd;

			SDA_c_pull_mid = (c_pull_mid) ? 1'b1 : 1'bz;
		end else if (master == `MASTER_C) begin
			SCL_mpd = slave_scl_pd;
			SCL_mpu = slave_scl_pu;
			SCL_cpd = 1'b0;

			SDA_mpd = slave_sda_pd;
			SDA_mpu = slave_sda_pu;
			SDA_cpd = master_sda_pd;

			SDA_c_pull_mid = 1'bz;
		end
	end
end

assign SCL_mp = SCL_mpd | SCL_mpu;
assign SDA_mp = SDA_mpd | SDA_mpu;

//assign SCL_m_inout = (SCL_mpd) ? 1'b0 : (SCL_mpu) ? 1'b1 : 1'bz;
assign SCL_c_inout = (SCL_cpd) ? 1'b0 : 1'bz;

//assign SDA_m_inout = (SDA_mpd) ? 1'b0 : (SDA_mpu) ? 1'b1 : 1'bz;
assign SDA_c_inout = (SDA_cpd) ? 1'b0 : 1'bz;

endmodule // interface
