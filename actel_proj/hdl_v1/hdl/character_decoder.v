//TODO: At some point this module should just be dedicated to hex decoding... need to move everything else over to a shared bus architecture....
module character_decoder(
	input [7:0] in_char,
	input in_char_valid,
	
	output is_hex_char,
	output [3:0] hex_decode,
	output reg is_cmd,
	output reg [3:0] cmd,
	output is_eol
);

assign is_hex_char = (in_char_valid && (((in_char >= 8'h30) && (in_char <= 8'h39)) || ((in_char >= 8'h41) && (in_char <= 8'h46))));
assign hex_decode = (in_char <= 8'h40) ? in_char[3:0] : (in_char[3:0] + 4'd9);
assign is_eol = (in_char_valid && (in_char == 8'h0d || in_char == 8'h0A));

always @* begin
	is_cmd = 1'b0;
	cmd = 4'd0;

	if(in_char_valid) begin
		if(in_char >= 8'h61 && in_char <= 8'h66) begin
			is_cmd = 1'b1;
			cmd = in_char[3:0]-4'd1;
		end
	end
end

endmodule

