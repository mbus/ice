`include "include/ice_def.v"

module debounce_ms(
  input wire clk_in,
  input wire db_in,

  output reg db_out
);

reg [15:0] db_shift;

always @(posedge clk_in) begin
  db_shift <= `SD {db_shift[14:0],db_in};
  db_out <= `SD db_shift[15] & db_shift[14] & db_shift[13] & db_shift[12] & db_shift[11]; 
end

endmodule
