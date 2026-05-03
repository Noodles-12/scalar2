`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(clk, instr_a, instr_b, cdb_arr,
                        str_op_a, str_op_b);
    input logic clk;
    input rs_entry instr_a, instr_b;
    input cdb_entry cdb_arr [0:3];

    output store_rs_entry str_op_a, str_op_b;

    rs_entry instr_a_reg, instr_b_reg;

    // Should be treated like a queue/FIFO array
    // Stores forced to execute in-order
    store_rs_entry store_buffer [0:7];  
    store_rs_entry next_store_buffer [0:7];

    // Can act like a regular RS
    // Loads can happen out-of-order as long as no previous stores (tracked by count)
    load_rs_entry load_buffer [0:7];
    load_rs_entry next_load_buffer [0:7];
    
    logic [0:3] store_head = 0, store_tail = 0, store_count = 0;
    logic [0:3] next_store_head, next_store_tail, next_store_count;

    logic [0:3] load_count = 0, next_load_count = 0;

    logic done, head_done;

    initial begin
        for(int i = 0; i < 8; i++)
            load_buffer[i] = '0;
    end

    always_ff @ (posedge clk) begin
        instr_a_reg <= instr_a;
        instr_b_reg <= instr_b;

        store_buffer <= next_store_buffer;
        load_buffer <= next_load_buffer;

        store_head <= next_store_head;
        store_tail <= next_store_tail;
        store_count <= next_store_count;

        load_count <= next_load_count;
    end

    always_comb begin
        next_store_buffer = store_buffer;
        next_load_buffer = load_buffer;

        next_store_head = store_head;
        next_store_tail = store_tail;
        next_store_count = store_count;

        next_load_count = load_count;

        str_op_a = '0;
        str_op_b = '0;
        head_done = 0;

        // Pushing first ready store
        if(next_store_buffer[next_store_head].check1 && next_store_buffer[next_store_head].check2) begin
            str_op_a = next_store_buffer[next_store_head];
            next_store_buffer[next_store_head] = 0;
            next_store_head = (next_store_head == 7) ? 0 : next_store_head + 1;
            if(next_store_count > 0) next_store_count--;
            head_done = 1;

            // Decrement the count on each load
            for(int i = 0; i < 8; i++) begin
                if(next_load_buffer[i] == 0 || next_load_buffer[i].count == 0) continue;
                next_load_buffer[i].count--;
            end
        end

        // Pushes next one if possible
        if(head_done && next_store_buffer[next_store_head].check1 && next_store_buffer[next_store_head].check2) begin
            str_op_b = next_store_buffer[next_store_head];
            next_store_buffer[next_store_head] = 0;
            next_store_head = (next_store_head == 7) ? 0 : next_store_head + 1;
            if(next_store_count > 0) next_store_count--;

            // Decrement the count on each load
            for(int i = 0; i < 8; i++) begin
                if(next_load_buffer[i] == 0 || next_load_buffer[i].count == 0) continue;
                next_load_buffer[i].count--;
            end
        end

        // Inserting instruction A
        case (instr_a_reg.load_rs.opcode)
            28 : begin
                done = 0;
                for(int i = 0; i < 8; i++) begin
                    if(!done && (load_buffer[i] == 0)) begin
                        next_load_buffer[i] = instr_a_reg;
                        next_load_buffer[i].count = next_store_count;
                        next_load_count++;
                        done = 1;
                    end
                end
            end
            29 : begin
                next_store_buffer[next_store_tail] = instr_a_reg;
                next_store_tail = (next_store_tail == 7) ? 0 : next_store_tail + 1;
                next_store_count++;
            end
        endcase

        // Inserting instruction B
        case (instr_b_reg.load_rs.opcode)
            28 : begin
                done = 0;
                for(int i = 0; i < 8; i++) begin
                    if(!done && (next_load_buffer[i] == 0)) begin
                        next_load_buffer[i] = instr_b_reg;
                        next_load_buffer[i].count = next_store_count;
                        next_load_count++;
                        done = 1;
                    end
                end
            end
            29 : begin
                next_store_buffer[next_store_tail] = instr_b_reg;
                next_store_tail = (next_store_tail == 7) ? 0 : next_store_tail + 1;
                next_store_count++;
            end
        endcase
    end
endmodule
