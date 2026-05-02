`timescale 1ns / 1ps

import config_pkg::*;

module dispatch_demux_1x4(data, code, op);    
    input rs_entry data;
    input [0:1] code;
    
    output rs_entry op [0:3];
    
    always_comb begin
        for(int i = 0; i < 4; ++i) begin
            op[i] = (i == code) ? data : 0;
        end
    end
endmodule

module rs_demux1x16(data, code, op);    
    input int_rs_entry data;
    input [0:3] code;
    
    output int_rs_entry op [0:15];
    
    always_comb begin
        for(int i = 0; i < 16; ++i) begin
            op[i] = (i == code) ? data : 0;
        end
    end
endmodule