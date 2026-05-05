`timescale 1ns / 1ps

import config_pkg::*;

module reorder_buffer(clk, input_a, input_b, cdb_arr, str_rob,
                        output_arr, id_to_free, uncommitted_stores);
    input logic clk;
    input rob_entry input_a, input_b;
    input cdb_entry cdb_arr [0:3];
    input str_rob_entry str_rob [0:1];

    output rob_entry output_arr [0:3];
    output logic [0:5] id_to_free [0:3];
    output logic [0:5] uncommitted_stores;
    logic [0:5] uncommitted_stores_reg = '0, next_uncommitted_stores;

    assign uncommitted_stores = uncommitted_stores_reg;

    rob_entry buffer [0:63] = '{default: '0};
    rob_entry next_buffer [0:63];

    logic [0:5] head = 0, tail = 0, count = 0;
    logic [0:5] next_head, next_tail, next_count;

    logic empty, full, done;

    assign empty = (head == tail) & (count == 0);
    assign full = (head == tail) & (count > 0);

    always_ff @ (posedge clk) begin
        buffer <= next_buffer;
        head <= next_head;
        tail <= next_tail;
        count <= next_count;
        uncommitted_stores_reg <= next_uncommitted_stores;
    end

    always_comb begin
        next_buffer = buffer;
        next_head = head;
        next_tail = tail;
        next_count = count;

        done = '0;
        output_arr = '{default: '0};
        id_to_free = '{default: '0};
        next_uncommitted_stores = uncommitted_stores_reg;

        // Inserting into buffer
        if(input_a != 0 && !full) begin
            next_buffer[next_tail] = input_a;
            next_tail = (next_tail == 63) ? 0 : next_tail + 1;
            next_count++;
            if(input_a.is_store == 1) begin
                next_uncommitted_stores++;
            end
        end

        if(input_b != 0 && !full) begin
            next_buffer[next_tail] = input_b;
            next_tail = (next_tail == 63) ? 0 : next_tail + 1;
            next_count++;
            if(input_b.is_store == 1) begin
                next_uncommitted_stores++;
            end
        end

        // Pushing into commit (removing)
        // Basically does what the commit stage should
        for(int i = 0; i < 4; i++) begin
            if(!done && next_buffer[next_head].done == 1) begin
                if(next_buffer[next_head].is_store == 1) begin
                    next_uncommitted_stores--;
                end
                output_arr[i] = next_buffer[next_head];
                id_to_free[i] = next_buffer[next_head].id;
                next_buffer[next_head] = '0;
                next_head = (next_head == 63) ? 0 : next_head + 1;
                next_count--;
            end else begin
                output_arr[i] = '0;
                id_to_free[i] = '0;
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

        // Changing with str_rob info
        for(int i = 0; i < 2; i++) begin
            if(str_rob[i] == 0) continue;

            for(int j = 0; j < 63; j++) begin
                if(next_buffer[j].id == str_rob[i].id) begin
                    next_buffer[j].mem_dest = str_rob[i].mem_dest;
                    next_buffer[j].result = str_rob[i].value;
                    next_buffer[j].done = 1;
                end
            end 
        end
    end
endmodule
