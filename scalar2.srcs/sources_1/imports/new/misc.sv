`timescale 1ns / 1ps

import config_pkg::*;

module dispatch_demux_1x4(
    input logic clk, 
    input logic rst, 
    input rs_entry data, 
    input logic [1:0] code, 
    
    output rs_entry op [0:3]
);
    always_ff @ (posedge clk) begin
        if(rst) begin
            for(int i = 0; i < 4; ++i) begin
                op[i] <= '0;
            end
        end else begin
            for(int i = 0; i < 4; ++i) begin
                op[i] <= (i == code) ? data : '0;
            end
        end
    end
endmodule
