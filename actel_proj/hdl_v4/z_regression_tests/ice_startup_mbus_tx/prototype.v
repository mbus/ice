module test ();

    reg [8*255:0]   cmd;
    reg [15:0]      cmd_size;


    function [3:0] asciiToNum;
        input [7:0] ascii;
        // < '0'
        if (ascii < 8'h30) $fatal(1);
        // '0' - '9'
        else if ( ascii < 8'h3A) asciiToNum = ascii - 8'h30; // '0'
        else if (ascii < 8'h41) $fatal(1);
        else if (ascii < 8'h47) asciiToNum = ascii - 8'h41 + 8'd10; //'A'=10
        else if (ascii < 8'h61) $fatal(1);
        else if (ascii < 8'h67) asciiToNum = ascii - 8'h61 + 8'd10; //'a'=10
        else $fatal(1);
    endfunction 

    function [7:0] toByte;
        input [15:0] hex_string;
        toByte[7:4] = asciiToNum(hex_string[15:8]);
        toByte[3:0] = asciiToNum(hex_string[7:0]);
        //$display("%h", toByte);
    endfunction

    task send_command;
        input [8*255:0] cmd; // 1 extra bit?
        input [15:0]    cmd_size; // only 8 needed?
        integer i;

        reg [15:0] msb;
        reg [15:0] work;
        reg [7:0] result;

        for (i = cmd_size-1 ; i >= 0; i = i - 1) begin
            msb= (1+i)*16  - 1;
            work[15] = cmd[msb];
            work[14] = cmd[msb-1];
            work[13] = cmd[msb-2];
            work[12] = cmd[msb-3];
            work[11] = cmd[msb-4];
            work[10] = cmd[msb-5];
            work[9]  = cmd[msb-6];
            work[8]  = cmd[msb-7];
            work[7]  = cmd[msb-8];
            work[6]  = cmd[msb-9];
            work[5]  = cmd[msb-10];
            work[4]  = cmd[msb-11];
            work[3]  = cmd[msb-12];
            work[2]  = cmd[msb-13];
            work[1]  = cmd[msb-14];
            work[0]  = cmd[msb-15];

            result = toByte(work);
            $display ("result: %h", result);
        end

    endtask 

    initial
    begin

        cmd = "620A08f0123450deadbeef";
        cmd_size = 16'd11;

        $display("cmd: %s ", cmd);
        
        send_command(cmd, cmd_size);
      
    end

endmodule
