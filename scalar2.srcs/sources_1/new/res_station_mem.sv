`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(clk, instr_a, instr_b, cdb_arr, uncommitted_stores, fwd_vals,
                        str_op_a, str_op_b);
    input logic clk;
    input rs_entry instr_a, instr_b;
    input cdb_entry cdb_arr [0:3];
    input logic [0:5] uncommitted_stores;
    input str_rob_entry fwd_vals [0:1];

    output store_rs_entry str_op_a, str_op_b;

    rs_entry instr_a_reg, instr_b_reg;

    // Both load & stores can happen out of order
    store_rs_entry store_buffer [0:7];  
    store_rs_entry next_store_buffer [0:7];

    logic [0:2] s_head = 0, s_tail = 0;
    logic [0:2] next_s_head, next_s_tail;

    load_rs_entry load_buffer [0:7];
    load_rs_entry next_load_buffer [0:7];

    logic [0:2] l_head = 0, l_tail = 0;
    logic [0:2] next_l_head, next_l_tail;
    
    logic [0:3] store_count = 0, next_store_count = 0;
    logic [0:3] load_count = 0, next_load_count = 0;

    logic done;
    logic done_a, done_b;

    initial begin
        for(int i = 0; i < 8; i++) begin
            load_buffer[i] = '0;
            store_buffer[i] = '0;
        end
    end

    always_ff @ (posedge clk) begin
        instr_a_reg <= instr_a;
        instr_b_reg <= instr_b;

        store_buffer <= next_store_buffer;
        load_buffer <= next_load_buffer;

        store_count <= next_store_count;
        load_count <= next_load_count;
    end

    always_comb begin
        next_store_buffer = store_buffer;
        next_load_buffer = load_buffer;

        next_store_count = store_count;
        next_load_count = load_count;

        str_op_a = '0;
        str_op_b = '0;
        
        done_a = 0;
        done_b = 0;

        // Forward ready store values into entry eff_addr field
        for(int i = 0; i < 8; i++) begin
            if(next_store_buffer[i].id == fwd_vals[0].id) begin
                next_store_buffer[i].eff_addr = fwd_vals[0].mem_dest;
            end else if (next_store_buffer[i].id == fwd_vals[1].id) begin 
                next_store_buffer[i].eff_addr = fwd_vals[1].mem_dest;
            end
        end

        // Dispatching ready stores OoO
        for(int i = 0; i < 8; i++) begin
            if(next_store_buffer[i].check1 && next_store_buffer[i].check2) begin
                if(!done_a) begin
                    str_op_a = next_store_buffer[i];
                    done_a = 1;
                end else if (!done_b) begin
                    str_op_b = next_store_buffer[i];
                    done_b = 1;
                end
            end
        end

        // Inserting instruction A In-Order
        case (instr_a_reg.load_rs.opcode)
            28 : begin
                next_load_buffer[next_l_tail] = instr_a_reg;
                next_load_buffer[next_l_head].count = next_store_count;
                next_load_count++;
                next_l_tail = next_l_tail + 1;
            end
            29 : begin
                next_store_buffer[next_s_tail] = instr_a_reg;
                next_store_count++;
                next_s_tail = next_s_tail + 1;
            end
        endcase

        // Inserting instruction B In-Order
        case (instr_b_reg.load_rs.opcode)
            28 : begin
                next_load_buffer[next_l_tail] = instr_b_reg;
                next_load_buffer[next_l_head].count = next_store_count;
                next_load_count++;
                next_l_tail = next_l_tail + 1;
            end
            29 : begin
                next_store_buffer[next_s_tail] = instr_b_reg;
                next_store_count++;
                next_s_tail = next_s_tail + 1;
            end
        endcase
    end
endmodule
