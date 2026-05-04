`timescale 1ns / 1ps

import config_pkg::*;

// Try different method besides next_* pattern
module data_memory(clk, rst, commit_arr);
    input logic clk, rst;
    input rob_entry commit_arr [0:3];

    rob_entry commit_arr_reg [0:3];

    logic [0:DATABUS_WIDTH - 1] memory [0:DATA_MEM_SIZE - 1];

    mem_write_entry write_arr [0:3];

    always_ff @ (posedge clk) begin
        if(rst) begin
            for(int i = 0; i < DATA_MEM_SIZE - 1; i++) begin
                memory[i].valid <= 0;
            end
        end else begin
            commit_arr_reg <= commit_arr;
        end
    end

    always_comb begin
        for(int i = 0; i < 4; i++) begin
            if(!commit_arr_reg[i].is_store) continue;

        end
    end
endmodule
