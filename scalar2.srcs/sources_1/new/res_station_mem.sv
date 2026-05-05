`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(clk, instr_a, instr_b, cdb_arr, uncommitted_stores,
                        str_op_a, str_op_b);
    input logic clk;
    input rs_entry instr_a, instr_b;
    input cdb_entry cdb_arr [0:3];
    input logic [0:5] uncommitted_stores;

    output store_rs_entry str_op_a, str_op_b;

    rs_entry instr_a_reg, instr_b_reg;

    // Both load & stores can happen out of order
    store_rs_entry store_buffer [0:7];  
    store_rs_entry next_store_buffer [0:7];

    load_rs_entry load_buffer [0:7];
    load_rs_entry next_load_buffer [0:7];
    
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

        // Dispatching ready stores
        for(int i = 0; i < 8; i++) begin
            if(next_store_buffer[i].check1 && next_store_buffer[i].check2) begin
                if(!done_a) begin
                    str_op_a = next_store_buffer[i];
                    done_a = 1;
                    next_store_buffer[i] = 0;
                end else if (!done_b) begin
                    str_op_b = next_store_buffer[i];
                    done_b = 1;
                    next_store_buffer[i] = 0;
                end
            end
        end

        // Inserting instruction A
        case (instr_a_reg.load_rs.opcode)
            28 : begin
                done = 0;
                for(int i = 0; i < 8; i++) begin
                    if(!done && (load_buffer[i] == 0)) begin
                        next_load_buffer[i] = instr_a_reg;
                        next_load_buffer[i].count = uncommitted_stores;
                        next_load_count++;
                        done = 1;
                    end
                end
            end
            29 : begin
                done = 0;
                for(int i = 0; i < 8; i++) begin
                    if(!done && (store_buffer[i] == 0)) begin
                        next_store_buffer[i] = instr_a_reg;
                        next_store_count++;
                        done = 1;
                    end
                end
            end
        endcase

        // Inserting instruction B
        case (instr_b_reg.load_rs.opcode)
            28 : begin
                done = 0;
                for(int i = 0; i < 8; i++) begin
                    if(!done && (next_load_buffer[i] == 0)) begin
                        next_load_buffer[i] = instr_b_reg;
                        next_load_buffer[i].count = uncommitted_stores;
                        next_load_count++;
                        done = 1;
                    end
                end
            end
            29 : begin
                done = 0;
                for(int i = 0; i < 8; i++) begin
                    if(!done && (next_store_buffer[i] == 0)) begin
                        next_store_buffer[i] = instr_b_reg;
                        next_store_count++;
                        done = 1;
                    end
                end
            end
        endcase
    end
endmodule
