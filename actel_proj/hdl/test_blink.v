// test_blink.v
module test_blink(
    input SYS_CLK,
    input [1:1] PB, //These are active-low!
    //input [4:1] DIP_SW,
    output reg [8:1] LED,

    input USB_UART_TXD,
    output USB_UART_RXD

    /*output FPGA_PINT_RESETN,
    output FPGA_PINT_RDREQ,
    input FPGA_PINT_RDDATA,
    input FPGA_PINT_RDRDY,
    output FPGA_PINT_CLK,
    output FPGA_PINT_WRDATA,
    output FPGA_PINT_WRREQ,

    input FPGA_IO[23:0],
    input FPGA_SPI_TXD,
    input FPGA_SPI_CLKOUT,
    input FPGA_SPI_FSSOUT,
    input FPGA_SPI_RXD,

    output SCL_PU,
    output SDA_PU,
    output SDA_PD,
    output SCL_PD,
    output SCL_TRI,
    output SDA_TRI,
    input SCL_DISCRETE_BUF,
    input SDA_DISCRETE_BUF*/
);

/****
 * Tie all unused output ports to a constant
 ****/
/*assign USB_UART_RXD = 1'b1;

assign FPGA_PINT_RESETN = 1'b1;
assign FPGA_PINT_RDREQ = 1'b0;
assign FPGA_PINT_CLK = 1'b0;
assign FPGA_PINT_WRDATA = 1'b0;
assign FPGA_PINT_WRREQ = 1'b0;

assign SCL_PU = 1'b0;
assign SDA_PU = 1'b0;
assign SCL_PD = 1'b0;
assign SDA_PD = 1'b0;
assign SCL_TRI = 1'b0;
assign SDA_TRI = 1'b0;*/

/****
 * Actual code which makes the LEDs blink...
 ****/
reg [23:0] clock_counter;
always @(posedge SYS_CLK) begin
    LED[8] <= USB_UART_TXD;                    
    if(~PB[1]) begin
        clock_counter <= 24'd0;
        LED[7:1] <= 8'd0;
    end else begin
        clock_counter <= clock_counter + 24'd1;
        if(clock_counter == 24'd0) begin
            LED[7:1] <= LED[7:1] + 8'd1;
        end
    end
end

endmodule
