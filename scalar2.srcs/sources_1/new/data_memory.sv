`timescale 1ns / 1ps

import config_pkg::*;

module data_memory(
    input logic clk,
    input logic rst,
    input rob_entry commit_a,
    input rob_entry commit_b,
    input logic [ADDRBUS_SIZE-1:0] read_addr_a,
    input logic [ADDRBUS_SIZE-1:0] read_addr_b,

    output logic [DATABUS_WIDTH-1:0] read_data_a,
    output logic [DATABUS_WIDTH-1:0] read_data_b
);

    logic [0:DATABUS_WIDTH - 1] memory [0:DATA_MEM_SIZE - 1];

    always_ff @ (posedge clk) begin
        read_data_a <= memory[read_addr_a];
    end

    always_ff @ (posedge clk) begin
        read_data_b <= memory[read_addr_b];
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            for(int i = 0; i < DATA_MEM_SIZE; i++) begin
                memory[i] <= '0;
            end
        end else begin
            if(commit_a.reg_rob.code == ROB_STR) begin
                memory[commit_a.str_rob.mem_dest] <= commit_a.str_rob.value;
            end

            if(commit_b.reg_rob.code == ROB_STR) begin
                memory[commit_b.str_rob.mem_dest] <= commit_b.str_rob.value;
            end
        end
    end
endmodule
