// uart_to_i2c.v

module i2c_xmit(
	input clock,
	input reset,

	input [7:0] addr,
	input [31:0] data,

	input start,

	inout SDA,
	inout SCL,

	output busy,

	output sda,
	output SDA_drive_debug,
	output [7:0] byte_idx,
	output [3:0] state,
	output i2c_clock
);

// Clock divider 33MHz -> 100kHz I2C
//`define MAGIC (8'd21)
`define MAGIC (8'd168)

reg [7:0] div;
reg i2c_clock;

always @(posedge clock) begin
	if (reset) begin
		i2c_clock <= 0;
		div <= 0;
	end else begin
		if (div == `MAGIC) begin
			div <= 0;
			i2c_clock <= ~i2c_clock;
		end else begin
			div <= div + 8'b1;
		end
	end
end
// End clock div

// Debounced signals
reg SDA0, SDA1;
reg SCL0, SCL1;

reg sda;
reg scl;
always @(posedge clock) begin
	if (reset) begin
		sda <= 1;
		scl <= 1;
	end else begin
		SDA0 <= SDA;
		SDA1 <= SDA0;
		if ((SDA == SDA0) && (SDA0 == SDA1))
			sda <= SDA;

		SCL0 <= SCL;
		SCL1 <= SCL0;
		if ((SCL == SCL0) && (SCL0 == SCL1))
			scl <= SCL;
	end
end
// End debounce

reg bus_busy;
reg last_sda;
reg last_scl;
always @(posedge clock) begin
	if (reset) begin
		bus_busy <= 0;
	end else begin
		last_sda <= sda;
		last_scl <= scl;

		// SCL high and SDA goes low [start bit]
		if (last_scl && scl && last_sda && ~sda)
			bus_busy <= 1;

		// SCL high and SDA goes high [stop bit]
		if (last_scl && scl && ~last_sda && sda)
			bus_busy <= 0;
	end
end

reg _start;
reg [7:0] _data [7:0];
reg [7:0] _len;
reg _busy;
always @(posedge clock) begin
	if (reset) begin
		_start <= 0;
		_len <= 8'd5;
	end else begin
		if (start && ~_busy) begin
			_start <= 1'b1;
			
			_data[0] <= addr;
			_data[1] <= data[7:0];
			_data[2] <= data[15:8];
			_data[3] <= data[23:16];
			_data[4] <= data[31:24];

			_len <= 8'd5;
		end

		else if (_busy) begin
			_start <= 1'b0;
		end
	end
end

assign busy = _busy;

`define STATE_WIDTH 4
reg [`STATE_WIDTH-1:0] state;

`define STATE_NONE               (4'd0)
`define STATE_START              (4'd1)
`define STATE_FAKE_STOP          (4'd2)
`define STATE_START2             (4'd3)
`define STATE_BITS0_7_LOW_SET    (4'd4)
`define STATE_BITS0_7_LOW        (4'd5)
`define STATE_BITS0_7_HIGH_SET   (4'd6)
`define STATE_BITS0_7_HIGH       (4'd7)
`define STATE_ACK_LOW_SET        (4'd8)
`define STATE_ACK_LOW            (4'd9)
`define STATE_ACK_HIGH_GET       (4'd10)
`define STATE_ACK_HIGH           (4'd11)
`define STATE_STOP_LOW_SET       (4'd12)
`define STATE_STOP_LOW           (4'd13)
`define STATE_STOP_LOW_EXTRA     (4'd14)
`define STATE_STOP_HIGH_SET      (4'd15)

reg [3:0] bit_idx;
reg [7:0] byte_idx;

reg SDA_drive;
reg SCL_drive;

assign SDA = (SDA_drive) ? 1'b0 : 1'bz;
assign SCL = (SCL_drive) ? 1'b0 : 1'bz;

reg [1:0] delay;

assign SDA_drive_debug = SDA_drive;

always @(posedge i2c_clock or posedge reset) begin
	if (reset) begin
		SDA_drive <= 0;
		SCL_drive <= 0;

		state <= `STATE_NONE;
		bit_idx <= 4'd7;
		byte_idx <= 0;

		_busy <= 0;
		delay <= 0;
	end else begin

		case (state)
			`STATE_NONE:
				begin
					bit_idx <= 4'd7;
					byte_idx <= 0;

					if (_start && ~bus_busy) begin
						_busy <= 1;
						state <= `STATE_START;
						SDA_drive <= 1;
					end else begin
						_busy <= 0;
						SDA_drive <= 0;
						SCL_drive <= 0;
					end
				end

			`STATE_START:
				begin
					// TODO: We don't need to do this on every message [though we can]
					state <= `STATE_FAKE_STOP;
					SDA_drive <= 0;
				end

			`STATE_FAKE_STOP:
				begin
					state <= `STATE_START2;
					SDA_drive <= 1;
				end

			`STATE_START2:
				begin
					state <= `STATE_BITS0_7_LOW_SET;
					SCL_drive <= 1;
				end

			`STATE_BITS0_7_LOW_SET:
				begin
					state <= `STATE_BITS0_7_LOW;
					SDA_drive <= ~_data[byte_idx][bit_idx];
				end

			`STATE_BITS0_7_LOW:
				begin
					state <= `STATE_BITS0_7_HIGH_SET;
					SCL_drive <= 0;
				end

			`STATE_BITS0_7_HIGH_SET:
				begin
					state <= `STATE_BITS0_7_HIGH;
				end

			`STATE_BITS0_7_HIGH:
				begin
					SCL_drive <= 1;
					bit_idx <= bit_idx - 1;

					if (bit_idx) begin
						state <= `STATE_BITS0_7_LOW_SET;
					end else begin
						state <= `STATE_ACK_LOW_SET;
						SDA_drive <= 0;
					end
				end

			`STATE_ACK_LOW_SET:
				begin
					state <= `STATE_ACK_LOW;
				end

			`STATE_ACK_LOW:
				begin
					bit_idx <= 4'd7;
					SCL_drive <= 0;
					state <= `STATE_ACK_HIGH_GET;
				end

			`STATE_ACK_HIGH_GET:
				begin
					if (sda) begin
						// NACK
						state <= `STATE_START2;
					end else begin
						// ACK
						byte_idx <= byte_idx + 1;

						if ((byte_idx + 1) == _len) begin
							// End of message
							state <= `STATE_ACK_HIGH;
						end else begin
							// Need to send another byte
							state <= `STATE_START2;
						end
					end
				end

			`STATE_ACK_HIGH:
				begin
					state <= `STATE_STOP_LOW_SET;
					SCL_drive <= 1;
				end

			`STATE_STOP_LOW_SET:
				begin
					SDA_drive <= 1;
					state <= `STATE_STOP_LOW;
				end

			`STATE_STOP_LOW:
				begin
					SCL_drive <= 0;
					state <= `STATE_STOP_LOW_EXTRA;
					delay <= 0;
				end

			`STATE_STOP_LOW_EXTRA:
				begin
					// Need some extra delay here to prevent start/stop glitches as everything rises for final stop bit
					if (delay < 2'd2) begin
						delay <= delay + 2'd1;
					end else begin
						state <= `STATE_STOP_HIGH_SET;
					end
				end

			`STATE_STOP_HIGH_SET:
				begin
					SDA_drive <= 0;
					state <= `STATE_NONE;
					_busy <= 0;
				end
		endcase
	end // ~reset
end // always posedge

endmodule // i2c_xmit
