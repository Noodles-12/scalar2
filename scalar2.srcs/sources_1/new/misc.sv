`timescale 1ns / 1ps

// Use code 0 to do nothing/go no where
module demux_1x8(data, code, op);    
    input [0:29] data;
    input [2:0] code;
    
    output logic [0:29] op [0:7];
    
    always_comb begin
        for(int i = 0; i < 8; ++i) begin
            op[i] = (i == code) ? data : 0;
        end
    end
    
endmodule