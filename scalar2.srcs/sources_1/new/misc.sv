`timescale 1ns / 1ps

import config_pkg::*;

module demux_1x4(data, code, op);    
    input [0:29] data;
    input [1:0] code;
    
    output logic [0:29] op [0:3];
    
    always_comb begin
        for(int i = 0; i < 4; ++i) begin
            op[i] = (i == code) ? data : 0;
        end
    end
    
endmodule

module rs_int_demux_1x16(data, code, op);    
    input int_rs_entry data;
    input [0:3] code;
    
    output logic int_rs_entry op [0:15];
    
    always_comb begin
        for(int i = 0; i < 16; ++i) begin
            op[i] = (i == code) ? data : 0;
        end
    end
    
endmodule