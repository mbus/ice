module double_latch(
    input   clk, 
    input   reset,
    input   async,
    output  dlatched
    );

reg lat1, lat2;
assign dlatched = lat2;

always @(posedge clk)
begin
    if (reset) begin
        lat1 <= `SD 0;
        lat2 <= `SD 0;
    end else begin
        lat1 <= `SD async;
        lat2 <= `SD lat1;
    end
end
endmodule
