`include "include/ice_def.v"

module sync (
    input       clk,
    input       async,
    output      sync
    );

    // Create a syncronized reset signal
    reg syn0;
    reg syn1;

    assign sync = syn1;

    //only place posedge reset allowed
    always @ (posedge clk or posedge async) begin
        if (async)  begin
            syn0 <= `SD 1'b1;
            syn1 <= `SD 1'b1;
        end
        else begin
            syn0 <= `SD 1'b0;
            syn1 <= `SD syn0;
        end
    end

endmodule


