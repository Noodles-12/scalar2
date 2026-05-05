`timescale 1ns / 1ps

import config_pkg::*;

module data_memory(clk, rst, commit_arr);
    input logic clk, rst;
    input rob_entry commit_arr [0:3];

    logic [0:DATABUS_WIDTH - 1] memory [0:DATA_MEM_SIZE - 1];

    always_ff @ (posedge clk) begin
        if(rst) begin
            for(int i = 0; i < DATA_MEM_SIZE; i++) begin
                memory[i] <= 0;
            end
        end else begin
            for(int i = 0; i < 4; i++) begin
                if(!commit_arr[i].is_store) continue;
                memory[commit_arr[i].mem_dest] <= commit_arr[i].result;
                $display("Data_mem[%d] -> %d", commit_arr[i].mem_dest, commit_arr[i].result);
            end
        end
    end
endmodule
