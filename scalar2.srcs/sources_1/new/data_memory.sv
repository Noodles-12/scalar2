`timescale 1ns / 1ps

import config_pkg::*;

module data_memory(clk, rst, commit_arr, read_addr,
                    read_data);
    input logic clk, rst;
    input rob_entry commit_arr [0:1];
    input [0:ADDRBUS_SIZE - 1] read_addr;

    output logic [0:DATABUS_WIDTH - 1] read_data;

    rob_entry write_queue [0:7], next_write_queue [0:7];

    logic [0:2] wq_head, wq_tail;
    logic [0:2] next_wq_head, next_wq_tail;

    (* ram_style = "block" *) logic [0:DATABUS_WIDTH - 1] memory [0:DATA_MEM_SIZE - 1];

    initial begin
        $readmemh("data_mem_init.mem", memory);
    end

    always_comb begin
        next_write_queue = write_queue;
        next_wq_tail = wq_tail;
        next_wq_head = wq_head;

        // Push slot 0
        if(commit_arr[0].is_store) begin
            next_write_queue[next_wq_tail] = commit_arr[0];
            next_wq_tail = next_wq_tail + 1;
        end

        // Push slot 1
        if(commit_arr[1].is_store) begin
            next_write_queue[next_wq_tail] = commit_arr[1];
            next_wq_tail = next_wq_tail + 1;
        end

        // Drain one per cycle into BRAM
        if(next_wq_head != next_wq_tail) begin
            next_wq_head = next_wq_head + 1;
        end
    end

    always_ff @ (posedge clk) begin
        write_queue <= next_write_queue;
        wq_tail <= next_wq_tail;
        wq_head <= next_wq_head;
    end

    always_ff @ (posedge clk) begin
        if(wq_head != wq_tail)
            memory[write_queue[wq_head].mem_dest] <= write_queue[wq_head].result;

        // Memory read
        read_data <= memory[read_addr];
    end
endmodule
