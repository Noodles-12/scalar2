`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(clk, rst, instr_a, instr_b, cdb_arr, uncommitted_stores, fwd_vals,
                        str_op_a, str_op_b);
    input logic clk, rst;
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

    logic done, done_a, done_b;
    logic [0:2] idx, real_count;
    logic count_ok, addrs_valid, store_ready, not_dispatched, equal_addrs;

    always_ff @ (posedge clk) begin
        if(rst) begin
            store_buffer <= '{default: '0};
            load_buffer <= '{default: '0};

            instr_a_reg <= '0;
            instr_b_reg <= '0;

            s_head <= '0;
            s_tail <= '0;

            l_head <= '0;
            l_tail <= '0;

            store_count <= '0;
            load_count <= '0;
        end else begin
            instr_a_reg <= instr_a;
            instr_b_reg <= instr_b;

            store_buffer <= next_store_buffer;
            load_buffer <= next_load_buffer;

            store_count <= next_store_count;
            load_count <= next_load_count;

            s_head <= next_s_head;
            s_tail <= next_s_tail;

            l_head <= next_l_head;
            l_tail <= next_l_tail;
        end
    end

    always_comb begin
        next_store_buffer = store_buffer;
        next_load_buffer = load_buffer;

        next_store_count = store_count;
        next_load_count = load_count;

        next_s_head = s_head;
        next_s_tail = s_tail;

        next_l_head = l_head;
        next_l_tail = l_tail;

        str_op_a = '0;
        str_op_b = '0;
        
        done_a = 0;
        done_b = 0;

        idx = '0;
        real_count = '0;

        count_ok = 0;
        addrs_valid = 0;
        store_ready = 0;
        not_dispatched = 0;
        equal_addrs = 0;

        // Forward ready store values into entry eff_addr field
        for(int i = 0; i < 8; i++) begin
            if(next_store_buffer[i].id == fwd_vals[0].id) begin
                next_store_buffer[i].eff_addr = fwd_vals[0].mem_dest;
            end else if (next_store_buffer[i].id == fwd_vals[1].id) begin 
                next_store_buffer[i].eff_addr = fwd_vals[1].mem_dest;
            end
        end

        // Get any ready load effective addresses calculated (TESTING)
        done_a = 0; 
        done_b = 0;
        for(int i = 0; i < 8; i++) begin
            if(next_load_buffer[i].base_ready && !next_load_buffer[i].dispatched && !next_load_buffer[i].valid_addr) begin
                $display("Load ID %d is ready", next_load_buffer[i].id);
            end
        end

        // Forward ready store values to lood instructions with same address
        // Loads should only check the most recent store in front of it
        for(int i = 0; i < 8; i++) begin
            idx = next_s_tail;
            for(int j = 0; j < 8; j++) begin
                if(next_store_buffer[idx] != 0) begin
                    real_count = real_count + 1;
                    idx = idx - 1;
                end

                count_ok = (next_load_buffer[i].count >= real_count);
                addrs_valid = (next_load_buffer[i].valid_addr && next_store_buffer[idx].valid_addr);
                store_ready = next_store_buffer[idx].check2;
                not_dispatched = !next_load_buffer[i].dispatched;
                equal_addrs = next_load_buffer[i].eff_addr == next_store_buffer[idx].eff_addr;

                if(count_ok && addrs_valid && store_ready && not_dispatched && equal_addrs) begin
                    $display("Match found: Load %d and Store %d at address %d",
                            next_load_buffer[i].id,
                            next_store_buffer[idx].id,
                            next_load_buffer[i].eff_addr);
                    //next_load_buffer[i].fwd_val = next_store_buffer[idx].value2;
                    //next_load_buffer[i].fwd_ready = 1;
                end
            end
        end

        // Dispatching ready stores OoO
        done_a = 0; 
        done_b = 0;
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
