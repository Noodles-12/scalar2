`timescale 1ns / 1ps

import config_pkg::*;

module reorder_buffer(clk, input_a, input_b, cdb_arr, str_rob,
                        output_arr, id_to_free);

    input logic clk;
    input rob_entry input_a, input_b;
    input cdb_entry cdb_arr [0:3];
    input str_rob_entry str_rob [0:1];

    output rob_entry output_arr [0:3];
    output logic [0:5] id_to_free [0:3];

    rob_entry buffer [0:63] = '{default: '0};
    rob_entry next_buffer [0:63];

    logic [0:5] head = 0, commit_head = 0, tail = 0, count = 0;
    logic [0:5] next_head, next_commit_head, next_tail, next_count;

    logic empty, full, done;

    assign empty = (head == tail) & (count == 0);
    assign full = (head == tail) & (count > 0);

    always_ff @ (posedge clk) begin
        buffer <= next_buffer;
        head <= next_head;
        tail <= next_tail;
        count <= next_count;
        commit_head <= next_commit_head;
    end

    always_comb begin
        next_buffer = buffer;
        next_head = head;
        next_tail = tail;
        next_count = count;
        next_commit_head = commit_head;
        done = 0;

        // Inserting into buffer
        if(input_a != 0 && !full) begin
            next_buffer[next_tail] = input_a;
            next_tail = (next_tail == 63) ? 0 : next_tail + 1;
            next_count++;
        end

        if(input_b != 0 && !full) begin
            next_buffer[next_tail] = input_b;
            next_tail = (next_tail == 63) ? 0 : next_tail + 1;
            next_count++;
        end

        // Pushing into commit (removing)
        // Basically does what the commit stage should
        for(int i = 0; i < 4; i++) begin
            if(!done && next_buffer[next_head].done == 1) begin
                output_arr[i] = next_buffer[next_head];
                id_to_free[i] = next_buffer[next_head].id;
                next_buffer[next_head] = 0;
                next_head = (next_head == 63) ? 0 : next_head + 1;
                next_count--;
            end else begin
                output_arr[i] = 0;
                done = 1;
            end
        end

        // Changing with CDB info
        for(int i = 0; i < 4; i++) begin
            if(cdb_arr[i] == 0) continue;

            for(int j = 0; j < 63; j++) begin
                if (next_buffer[j].id == cdb_arr[i].id) begin
                    next_buffer[j].result = cdb_arr[i].result;
                    next_buffer[j].done = 1;
                end
            end
        end
    end
    
endmodule
