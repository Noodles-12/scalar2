`timescale 1ns / 1ps

import config_pkg::*;

module data_memory(clk, rst, commit_arr, read_addr, 
                    read_data);
    input logic clk, rst;
    input rob_entry commit_arr [0:1];
    input [0:ADDRBUS_SIZE - 1] read_addr;

    output logic [0:DATABUS_WIDTH - 1] read_data;

    logic is_store, str_idx;

    always_comb begin
        is_store = 0;
        str_idx = 0;
        for(int i = 0; i < 2; i++) begin
            if(commit_arr[i].is_store) begin
                is_store = 1;
                str_idx = i[0];
            end
        end
    end

    (* ram_style = "block" *) logic [0:DATABUS_WIDTH - 1] memory [0:DATA_MEM_SIZE - 1];

    initial begin
        $readmemh("data_mem_init.mem", memory);
    end

    always_ff @(posedge clk) begin
        if(is_store) begin
            memory[commit_arr[str_idx].mem_dest] <= commit_arr[str_idx].result;
            $display("MEM[%0d] <= %0d | %t", commit_arr[str_idx].mem_dest, commit_arr[str_idx].result, $time);
        end

        read_data <= memory[read_addr];
    end
endmodule