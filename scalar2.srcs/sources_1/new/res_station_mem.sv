`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(clk, rst, instr_a, instr_b, cdb_arr, id_to_free,
                        str_fwd_vals, load_fwd_addrs,
                        str_op_a, str_op_b, load_to_fu_a, load_to_fu_b, load_disp_mem, load_disp_imm);
    input logic clk, rst;
    input rs_entry instr_a, instr_b;
    input cdb_entry cdb_arr [0:CDB_SIZE - 1];
    input logic [0:5] id_to_free [0:1];

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

    // Stage 0 - Get inputs
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

    // 1.A Free entries
    logic [0:MEM_RS_SIZE - 1] load_free_mask;
    logic [0:MEM_RS_SIZE - 1] store_free_mask;

    always_comb begin
        load_free_mask = '0;
        store_free_mask = '0;

        for(int i = 0; i < 2; i++) begin
            if(id_to_free[i] != 0) begin
                for(int j = 0; j < MEM_RS_SIZE; j++) begin
                    if(id_to_free[i] == load_buffer[j].id) load_free_mask[j] = 1;
                    if(id_to_free[i] == store_buffer[j].id) store_free_mask[j] = 1;
                end
            end
        end
    end

    store_rs_entry s1_store [0:7];
    load_rs_entry s1_load [0:7];
    logic [0:3] s1_store_count, s1_load_count;
    logic [0:2] s1_store_head, s1_store_tail;
    logic [0:2] s1_load_head, s1_load_tail;

    always_comb begin
        s1_store = store_buffer;
        s1_load = load_buffer;
        s1_store_count = store_count;
        s1_load_count = load_count;
        s1_store_head = s_head;
        s1_store_tail = s_tail;
        s1_load_head = l_head;
        s1_load_tail = l_tail;

        // This loop does the subtraction for each load count
        for(int j = 0; j < 8; j++) begin
            if(store_free_mask[j]) begin
                for(int k = 0; k < 8; k++) begin
                    if(s1_load[k].id != 0 && s1_load[k].count > 0)
                        s1_load[k].count = s1_load[k].count - 1;
                end
            end
        end

        // This loop actually zeros out entries & decrements count
        for(int j = 0; j < 8; j++) begin
            if(store_free_mask[j]) begin
                s1_store[j] = '0;
                s1_store_count = s1_store_count - 1;
            end

            if(load_free_mask[j])  begin
                s1_load[j] = '0;
                s1_load_count = s1_load_count - 1;
            end
        end
    end

    // 1.B CDB Update
    logic [0:MEM_RS_SIZE - 1] load_update_mask;
    logic [0:MEM_RS_SIZE - 1] store_update_mask_d;
    logic [0:MEM_RS_SIZE - 1] store_update_mask_s;

    always_comb begin
        load_update_mask = '0;
        store_update_mask_d = '0;
        store_update_mask_s = '0;

        for(int i = 0; i < CDB_SIZE; i++) begin
            if(cdb_arr[i].id != 0) begin
                for(int j = 0; j < MEM_RS_SIZE; j++) begin
                    if(cdb_arr[i].prf == s1_load[j].reg_s) load_update_mask[j] = 1;
                    if(cdb_arr[i].prf == s1_store[j].reg_d) store_update_mask_d[j] = 1;
                    if(cdb_arr[i].prf == s1_store[j].reg_s) store_update_mask_s[j] = 1;
                end
            end
        end
    end

    store_rs_entry s2_store [0:7];
    load_rs_entry s2_load [0:7];

    always_comb begin
        s2_store = s1_store;
        s2_load = s1_load;

        for(int i = 0; i < CDB_SIZE; i++) begin
            if(cdb_arr[i].id != 0) begin
                for(int j = 0; j < MEM_RS_SIZE; j++) begin
                    if(load_update_mask[j]) begin
                        s2_load[j].base_val = cdb_arr[i].result;
                        s2_load[j].base_ready = 1;
                    end
                    if(store_update_mask_d[j]) begin
                        s2_store[j].value1 = cdb_arr[i].result;
                        s2_store[j].check1 = 1;
                    end
                    if(store_update_mask_s[j]) begin
                        s2_store[j].value2 = cdb_arr[i].result;
                        s2_store[j].check2 = 1;
                    end
                end
            end
        end
    end

    // 1.C Get forwarded effective addresses from load FU
    logic [0:MEM_RS_SIZE - 1] load_effaddr_recv_mask_a, load_effaddr_recv_mask_b;
    
    always_comb begin
        load_effaddr_recv_mask_a = '0;
        load_effaddr_recv_mask_b = '0;

        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            // Probably a redundant invalid check but can't be too sure
            if(s2_load[i].id == load_fwd_addrs[0].id && s2_load[i].id != 0 && load_fwd_addrs[0].id != 0) 
                load_effaddr_recv_mask_a[i] = 1;
            if(s2_load[i].id == load_fwd_addrs[1].id && s2_load[i].id != 0 && load_fwd_addrs[0].id != 0) 
                load_effaddr_recv_mask_b[i] = 1;
        end
    end

    store_rs_entry s3_store [0:7];
    load_rs_entry s3_load [0:7];

    always_comb begin
        s3_store = s2_store;
        s3_load = s2_load;

        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            // They shouldn't hit the same id
            if(load_effaddr_recv_mask_a[i] == 1) begin
                s3_load[i].eff_addr = load_fwd_addrs[0].eff_addr;
                s3_load[i].valid_addr = 1;
                s3_load[i].pending_addr = 0;
            end

            if(load_effaddr_recv_mask_b[i] == 1) begin
                s3_load[i].eff_addr = load_fwd_addrs[1].eff_addr;
                s3_load[i].valid_addr = 1;
                s3_load[i].pending_addr = 0;
            end
        end
    end

    // 1.D Store to Load Forwarding
    logic [0:MEM_RS_SIZE - 1] loads_with_matches;
    logic [0:2] match_str_idx [0:MEM_RS_SIZE];
    logic [0:2] idx;
    logic [0:3] real_count;
    logic stall, count_ok, valid_addr, str_ready, equal_addrs;

    always_comb begin
        loads_with_matches = '0;
        match_str_idx = '{default: '0};

        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            idx = s1_store_tail - 1;
            real_count = '0;
            stall = 0;
            for(int j = 0; j < MEM_RS_SIZE; j++) begin
                if(s3_load[i].id != 0 && s3_load[i].valid_addr && !s3_load[i].dispatched 
                && !s3_load[i].fwd_ready && !s3_load[i].pending_addr && !stall) begin
                    if(s3_store[idx].id != 0) real_count = real_count + 1;
                    
                    count_ok = (s3_load[i].count > (s1_store_count - real_count));
                    equal_addrs = s3_load[i].eff_addr == s3_store[idx].eff_addr;
                    str_ready = s3_store[idx].check2;
                    valid_addr = s3_store[idx].valid_addr;

                    if(!valid_addr && count_ok && s3_store[idx].id != 0) begin
                        stall = 1;
                    end

                    if(count_ok && valid_addr && str_ready && equal_addrs && s3_store[idx].id != 0) begin
                        loads_with_matches[i] = 1;
                        match_str_idx[i] = idx;
                        stall = 1;
                    end
                end
                idx = idx - 1;
            end
        end
    end

    store_rs_entry s4_store [0:7];
    load_rs_entry s4_load [0:7];

    always_comb begin
        s4_store = s3_store;
        s4_load = s3_load;

        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(loads_with_matches[i]) begin
                s4_load[i].fwd_val = s4_store[match_str_idx[i]].value2;
                s4_load[i].fwd_ready = 1;
            end
        end
    end

    // 1.E Inserting Instructions & head advancement
    store_rs_entry s5_store [0:7];
    load_rs_entry s5_load [0:7];
    logic [0:3] s5_store_count, s5_load_count;
    logic [0:2] s5_store_head, s5_store_tail;
    logic [0:2] s5_load_head, s5_load_tail;

    always_comb begin
        s5_store = s4_store;
        s5_store_count = s1_store_count;
        s5_store_head = s1_store_head;
        s5_store_tail = s1_store_tail;
        s5_load = s4_load;
        s5_load_count = s1_load_count;
        s5_load_head = s1_load_head;
        s5_load_tail = s1_load_tail;
        done_s = 0;
        done_l = 0;

        // Inserting instruction A In-Order
        case (instr_a_reg.load_rs.opcode)
            28 : begin
                s5_load[s5_load_tail] = instr_a_reg;
                s5_load[s5_load_tail].count = s5_store_count;
                s5_load_count = s5_load_count + 1;
                s5_load_tail = s5_load_tail + 1;
                $display("load %d being inserted | %t", instr_a_reg.load_rs.id, $time);
            end
            29 : begin
                s5_store[s5_store_tail] = instr_a_reg;
                s5_store_count = s5_store_count + 1;
                s5_store_tail = s5_store_tail + 1;
                $display("store %d being inserted | %t", instr_a_reg.store_rs.id, $time);
            end
        endcase

        // Inserting instruction B In-Order
        case (instr_b_reg.load_rs.opcode)
            28 : begin
                s5_load[s5_load_tail] = instr_b_reg;
                s5_load[s5_load_tail].count = s5_store_count;
                s5_load_count = s5_load_count + 1;
                s5_load_tail = s5_load_tail + 1;
                $display("load %d being inserted | %t", instr_b_reg.load_rs.id, $time);
            end
            29 : begin
                s5_store[s5_store_tail] = instr_b_reg;
                s5_store_count = s5_store_count + 1;
                s5_store_tail = s5_store_tail + 1;
                $display("store %d being inserted | %t", instr_b_reg.store_rs.id, $time);
            end
        endcase
    end

    // 1.F Buffer Head Incrementing
    store_rs_entry s6_store [0:7];
    load_rs_entry  s6_load  [0:7];
    logic [0:2] s6_store_head, s6_load_head;
    logic [0:2] s6_store_tail, s6_load_tail;
    logic [0:3] s6_store_count, s6_load_count;
    logic done_s, done_l;

    always_comb begin
        s6_store       = s5_store;
        s6_load        = s5_load;
        s6_store_head  = s5_store_head;
        s6_load_head   = s5_load_head;
        s6_store_tail  = s5_store_tail;
        s6_load_tail   = s5_load_tail;
        s6_store_count = s5_store_count;
        s6_load_count  = s5_load_count;
        done_s         = 0;
        done_l         = 0;

        // Advance store head past zeroed entries
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(!done_s) begin
                if(s6_store[s6_store_head].id == 0)
                    s6_store_head = s6_store_head + 1;
                else
                    done_s = 1;
            end
        end

        // Advance load head past zeroed entries
        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(!done_l) begin
                if(s6_load[s6_load_head].id == 0)
                    s6_load_head = s6_load_head + 1;
                else
                    done_l = 1;
            end
        end
    end

    /* logic [0:MEM_RS_SIZE - 1] load_effaddr_calc_mask;
    logic [0:3] need_forwarding_count;

    always_comb begin
        load_effaddr_calc_mask = '0;
        need_forwarding_count = '0;

        for(int i = 0; i < MEM_RS_SIZE; i++) begin
            if(s2_load[i].id == 0) continue;
            if(s2_load[i].base_ready && !s2_load[i].dispatched && !s2_load[i].fwd_ready 
            && !s2_load[i].pending_addr && !s2_load[i].valid_addr && need_forwarding_count <= 2) begin
                load_effaddr_calc_mask[i] = 1;
                need_forwarding_count = 2;
            end
        end
    end

    store_rs_entry s3_store [0:7];
    load_rs_entry s3_load [0:7];

    for(int i = 0; i < MEM_RS_SIZE; i++) begin
        if(s2_load[i].id == 0) continue;
        if(load_effaddr_calc_mask[i] == 1) begin
            
        end

    end */
endmodule
