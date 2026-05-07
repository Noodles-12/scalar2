`timescale 1ns / 1ps

import config_pkg::*;

// End goal is to either make this into a pipelined FSM for varying needed operations
// Or create each individual component to maximize utilization
module func_unit_load(clk, rst);
    input logic clk, rst;

    always_ff @ (posedge clk) begin
        if(rst) begin
            
        end else begin

        end
    end
endmodule
