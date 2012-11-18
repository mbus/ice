module character_encoder(
	input [7:0] char_in,
	input which_hex_char,
	
	output [7:0] out
);

//This module just hex-encodes an input character
wire [3:0] bin = (which_hex_char) ? char_in[3:0] : char_in[7:4];

assign out = (bin >= 4'hA) ? (8'h37 + bin) : (8'h30 + bin);

endmodule
