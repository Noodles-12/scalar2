`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(clk, rst, instr_a, instr_b, cdb_arr, id_to_free,
                        str_fwd_vals, load_fwd_addrs,
                        str_op_a, str_op_b, load_to_fu_a, load_to_fu_b, load_disp_mem, load_disp_imm);
    input logic clk, rst;
    input rs_entry instr_a, instr_b;
    input cdb_entry cdb_arr [0:CDB_SIZE - 1];
    input logic [0:5] id_to_free [0:3];

    input str_rob_entry str_fwd_vals [0:1];
    input load_fwd_addr load_fwd_addrs [0:1];

    output store_rs_entry str_op_a, str_op_b;
    output load_rs_entry load_to_fu_a, load_to_fu_b;
    output load_rs_entry load_disp_mem, load_disp_imm;

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
    logic count_ok, addrs_valid, store_ready, equal_addrs, no_fwd_yet, stall;

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

        load_to_fu_a = '0;
        load_to_fu_b = '0;

        load_disp_mem = '0;
        load_disp_imm = '0;

        count_ok = 0;
        addrs_valid = 0;
        store_ready = 0;
        equal_addrs = 0;
        no_fwd_yet = 0;
        stall = 0;

        // Free retired entries
        for(int i = 0; i < 4; i++) begin
            if(id_to_free[i] != 0) begin
                for(int j = 0; j < MEM_RS_SIZE; j++) begin
                    if(next_store_buffer[j].id == id_to_free[i]) begin
                        next_store_buffer[j] = '0;
                        next_store_count = next_store_count - 1;
                        for(int k = 0; k < MEM_RS_SIZE; k++) begin
                            if(next_load_buffer[k].id != 0 && next_load_buffer[k].count > 0)
                                next_load_buffer[k].count = next_load_buffer[k].count - 1;
                        end
                    end
                end
                for(int j = 0; j < MEM_RS_SIZE; j++) begin
                    if(next_load_buffer[j].id == id_to_free[i]) begin
                        $display("Match for entry to clear id %d", next_load_buffer[j].id);
                        next_load_buffer[j] = '0;
                        next_load_count = next_load_count - 1;
                    end
                end
            end
        end

        // Dispatching ready stores OoO
        done_a = 0;
        done_b = 0;
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(next_store_buffer[i].id != 0 && next_store_buffer[i].check1 && next_store_buffer[i].check2 && !next_store_buffer[i].dispatched) begin
                if(!done_a) begin
                    str_op_a = next_store_buffer[i];
                    next_store_buffer[i].dispatched = 1;
                    done_a = 1;
                end else if (!done_b) begin
                    str_op_b = next_store_buffer[i];
                    next_store_buffer[i].dispatched = 1;
                    done_b = 1;
                end
            end
        end

        // Dispatching ready loads OoO
        done_a = 0; 
        done_b = 0;
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(next_load_buffer[i].valid_addr && next_load_buffer[i].count == 0 && !next_load_buffer[i].dispatched && !done_a) begin
                $display("Dispatching load that needs to fetch from memory id: %d", next_load_buffer[i].id);
                load_disp_mem = next_load_buffer[i];
                next_load_buffer[i].dispatched = 1;
                done_a = 1;
            end

            if(next_load_buffer[i].valid_addr && next_load_buffer[i].fwd_ready && !next_load_buffer[i].dispatched && !done_b) begin
                $display("Dispatching load that got forwarded value id: %d", next_load_buffer[i].id);
                load_disp_imm = next_load_buffer[i];
                next_load_buffer[i].dispatched = 1;
                done_b = 1;
            end
        end

        // Get forwarded memory destination calculations from store FU for loads to check for similar addresses
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(next_store_buffer[i].id == str_fwd_vals[0].id) begin
                next_store_buffer[i].eff_addr = str_fwd_vals[0].mem_dest;
                next_store_buffer[i].valid_addr = 1;
            end else if (next_store_buffer[i].id == str_fwd_vals[1].id) begin 
                next_store_buffer[i].eff_addr = str_fwd_vals[1].mem_dest;
                next_store_buffer[i].valid_addr = 1;
            end
        end

        // Find first two loads ready to have their effective addresses calculated
        done_a = 0;
        done_b = 0;
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(!done_a && next_load_buffer[i].id != 0 && next_load_buffer[i].base_ready && !next_load_buffer[i].dispatched && !next_load_buffer[i].valid_addr) begin
                load_to_fu_a = next_load_buffer[i];
                next_load_buffer[i].dispatched = 1;
                done_a = 1;
            end else if (!done_b && next_load_buffer[i].id != 0 && next_load_buffer[i].base_ready && !next_load_buffer[i].dispatched && !next_load_buffer[i].valid_addr) begin
                load_to_fu_b = next_load_buffer[i];
                next_load_buffer[i].dispatched = 1;
                done_b = 1;
            end
        end

        // Get forwarded effective address values from load FU from previous cycle
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(load_fwd_addrs[0].id != 0 && next_load_buffer[i].id == load_fwd_addrs[0].id) begin
                next_load_buffer[i].eff_addr = load_fwd_addrs[0].eff_addr;
                next_load_buffer[i].dispatched = 0;
                next_load_buffer[i].valid_addr = 1;
            end else if (load_fwd_addrs[1].id != 0 && next_load_buffer[i].id == load_fwd_addrs[1].id) begin
                next_load_buffer[i].eff_addr = load_fwd_addrs[1].eff_addr;
                next_load_buffer[i].dispatched = 0;
                next_load_buffer[i].valid_addr = 1;
            end
        end

        // Forward ready store values to load instructions with same address
        // Loads should only check the most recent store in front of it
        // Should also stop if most recent leading store MIGHT have shared address
        for(int i = 0; i < MEM_RS_SIZE; i++) begin // Scanning through each load
            idx = next_s_tail - 1;
            real_count = '0;
            stall = 0;
            for(int j = 0; j < MEM_RS_SIZE; j++) begin
                if(next_load_buffer[i].id != 0 && next_load_buffer[i].valid_addr && !next_load_buffer[i].dispatched && !next_load_buffer[i].fwd_ready) begin
                    if(next_store_buffer[idx].id != 0) begin // Scanning each store for the load
                        real_count = real_count + 1;
                    end

                    count_ok = (next_load_buffer[i].count > (next_store_count - real_count));
                    addrs_valid = next_store_buffer[idx].valid_addr;
                    store_ready = next_store_buffer[idx].check2;
                    equal_addrs = next_load_buffer[i].eff_addr == next_store_buffer[idx].eff_addr;

                    // Stall if a real store in front of this load has no valid address yet
                    if(next_store_buffer[idx].id != 0 && count_ok && !next_store_buffer[idx].valid_addr) begin
                        stall = 1;
                    end

                    if(count_ok && addrs_valid && store_ready && equal_addrs) begin
                        next_load_buffer[i].fwd_val = next_store_buffer[idx].value2;
                        next_load_buffer[i].fwd_ready = 1;
                        stall = 1;
                    end
                end
                idx = idx - 1;
            end
        end

        for(int i = 0; i < CDB_SIZE; i++) begin
            if(cdb_arr[i] == 0) continue;
            // Check store buffer
            for(int j = 0; j < MEM_RS_SIZE; j++) begin
                if(next_store_buffer[j].id != 0 && next_store_buffer[j].reg_d == cdb_arr[i].prf && !next_store_buffer[j].check1) begin
                    next_store_buffer[j].value1 = cdb_arr[i].result;
                    next_store_buffer[j].check1 = 1;
                end

                if(next_store_buffer[j].id != 0 && next_store_buffer[j].reg_s == cdb_arr[i].prf && !next_store_buffer[j].check2) begin
                    next_store_buffer[j].value2 = cdb_arr[i].result;
                    next_store_buffer[j].check2 = 1;
                end
            end

            // Check load buffer
            for(int j = 0; j < MEM_RS_SIZE; j++) begin
                if(next_load_buffer[j].reg_s == cdb_arr[i].prf && !next_load_buffer[j].base_ready) begin
                    next_load_buffer[j].base_val = cdb_arr[i].result;
                    next_load_buffer[j].base_ready = 1;
                end
            end
        end

        // Inserting instruction A In-Order
        case (instr_a_reg.load_rs.opcode)
            28 : begin
                next_load_buffer[next_l_tail] = instr_a_reg;
                next_load_buffer[next_l_tail].count = next_store_count;
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
                next_load_buffer[next_l_tail].count = next_store_count;
                next_load_count++;
                next_l_tail = next_l_tail + 1;
            end
            29 : begin
                next_store_buffer[next_s_tail] = instr_b_reg;
                next_store_count++;
                next_s_tail = next_s_tail + 1;
            end
        endcase



        // Advance store head past retired (zeroed) entries
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(next_store_buffer[next_s_head].id == 0)
                next_s_head = next_s_head + 1;
            else break;
        end

        // Advance load head past retired (zeroed) entries
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(next_load_buffer[next_l_head].id == 0)
                next_l_head = next_l_head + 1;
            else break;
        end
    end
endmodule
