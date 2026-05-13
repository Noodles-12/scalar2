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
    logic [0:2] s_head, s_tail;

    load_rs_entry load_buffer [0:7];
    logic [0:2] l_head, l_tail;
    
    logic [0:3] store_count, load_count;

    logic done_a, done_b, done_c, done_d;
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

            store_buffer <= s8_store;
            load_buffer <= s8_load;

            store_count <= s6_store_count;
            load_count <= s6_load_count;

            s_head <= s6_store_head;
            s_tail <= s6_store_tail;

            l_head <= s6_load_head;
            l_tail <= s6_load_tail;
        end
    end

    always_ff @(posedge clk) begin
        if(!rst) begin
            // Load addr forwarding
            for(int i = 0; i < RS_SIZE; i++) begin
                if(load_buffer[i].id != 0 && !load_buffer[i].valid_addr && !load_buffer[i].pending_addr
                && load_buffer[i].base_ready)
                    $display("Load %0d waiting for eff_addr | %t", load_buffer[i].id, $time);
            end

            // Load eff_addr received
            for(int i = 0; i < RS_SIZE; i++) begin
                if(s3_load[i].valid_addr && !load_buffer[i].valid_addr)
                    $display("Load %0d eff_addr received | %t", s3_load[i].id, $time);
            end

            // Store eff_addr received
            for(int i = 0; i < RS_SIZE; i++) begin
                if(sx_store[i].valid_addr && !store_buffer[i].valid_addr)
                    $display("Store %0d eff_addr received | %t", sx_store[i].id, $time);
            end

            // Load dispatched to mem
            if(valid_disp_mem)
                $display("Dispatching load %0d to mem | %t", s7_load[load_disp_mem_idx].id, $time);

            // Load dispatched via forwarded val
            if(valid_disp_imm)
                $display("Dispatching load %0d via fwd | %t", s7_load[load_disp_imm_idx].id, $time);

            // Store dispatched to FU
            for(int i = 0; i < RS_SIZE; i++) begin
                if(store_dispatch_mask[i])
                    $display("Store %0d dispatched to FU | %t", s7_store[i].id, $time);
            end

            // Insertions
            if(instr_a_reg.load_rs.opcode == 28)
                $display("Load %0d inserted | %t", instr_a_reg.load_rs.id, $time);
            if(instr_a_reg.load_rs.opcode == 29)
                $display("Store %0d inserted | %t", instr_a_reg.load_rs.id, $time);
            if(instr_b_reg.load_rs.opcode == 28)
                $display("Load %0d inserted | %t", instr_b_reg.load_rs.id, $time);
            if(instr_b_reg.load_rs.opcode == 29)
                $display("Store %0d inserted | %t", instr_b_reg.load_rs.id, $time);

            // Frees
            for(int i = 0; i < 2; i++) begin
                if(id_to_free[i] != 0)
                    $display("id %0d freed | %t", id_to_free[i], $time);
            end
        end
    end

    // 1.A Free entries
    logic [0:RS_SIZE - 1] load_free_mask;
    logic [0:RS_SIZE - 1] store_free_mask;

    always_comb begin
        load_free_mask = '0;
        store_free_mask = '0;

        for(int i = 0; i < 2; i++) begin
            if(id_to_free[i] != 0) begin
                for(int j = 0; j < RS_SIZE; j++) begin
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

    logic [0:RS_SIZE-1] load_update_mask;
    logic [0:RS_SIZE-1] store_update_mask_d;
    logic [0:RS_SIZE-1] store_update_mask_s;

    logic [2:0] load_update_idx [0:RS_SIZE-1];
    logic [2:0] store_update_idx_d [0:RS_SIZE-1];
    logic [2:0] store_update_idx_s [0:RS_SIZE-1];

    always_comb begin
        load_update_mask = '0;
        store_update_mask_d = '0;
        store_update_mask_s = '0;

        load_update_idx = '{default: '0};
        store_update_idx_d = '{default: '0};
        store_update_idx_s = '{default: '0};

        for (int i = 0; i < CDB_SIZE; i++) begin
            if (cdb_arr[i].id == 0)
                continue;

            for (int j = 0; j < RS_SIZE; j++) begin
                if (s1_load[j].reg_s == cdb_arr[i].prf) begin
                    load_update_mask[j] = 1;
                    load_update_idx[j]  = i;
                end
            end

            for (int j = 0; j < RS_SIZE; j++) begin
                if (s1_store[j].reg_d == cdb_arr[i].prf) begin
                    store_update_mask_d[j] = 1;
                    store_update_idx_d[j]  = i;
                end
            end

            for (int j = 0; j < RS_SIZE; j++) begin
                if (s1_store[j].reg_s == cdb_arr[i].prf) begin
                    store_update_mask_s[j] = 1;
                    store_update_idx_s[j]  = i;
                end
            end
        end
    end

    store_rs_entry s2_store [0:7];
    load_rs_entry s2_load  [0:7];

    always_comb begin
        s2_store = s1_store;
        s2_load  = s1_load;

        // single pass over RS (cheap)
        for (int i = 0; i < RS_SIZE; i++) begin

            if (load_update_mask[i]) begin
                s2_load[i].base_val   = cdb_arr[load_update_idx[i]].result;
                s2_load[i].base_ready = 1;
            end

            if (store_update_mask_d[i]) begin
                s2_store[i].value1   = cdb_arr[store_update_idx_d[i]].result;
                s2_store[i].check1   = 1;
            end

            if (store_update_mask_s[i]) begin
                s2_store[i].value2   = cdb_arr[store_update_idx_s[i]].result;
                s2_store[i].check2   = 1;
            end
        end
    end

    // 1.C Get forwarded effective addresses from load FU
    store_rs_entry s3_store [0:7];
    load_rs_entry s3_load  [0:7];

    always_comb begin
        s3_store = s2_store;
        s3_load  = s2_load;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(s3_load[i].id == 0) continue;
            if(s3_load[i].valid_addr) continue;

            if(load_fwd_addrs[0].id != 0 &&
            s3_load[i].id == load_fwd_addrs[0].id) begin
                s3_load[i].eff_addr    = load_fwd_addrs[0].eff_addr;
                s3_load[i].valid_addr  = 1;
                s3_load[i].pending_addr = 0;
                //$display("Load A %d eff_addr received | %t", s3_load[i].id, $time);
            end

            else if(load_fwd_addrs[1].id != 0 && s3_load[i].id == load_fwd_addrs[1].id) begin
                s3_load[i].eff_addr    = load_fwd_addrs[1].eff_addr;
                s3_load[i].valid_addr  = 1;
                s3_load[i].pending_addr = 0;
                //$display("Load B %d eff_addr received | %t", s3_load[i].id, $time);
            end
        end
    end

    // 1.D Get forwarded effective addresses from store FU
    // Naming these intermediary store/load buffers to sx_* to not have to refactor names
    store_rs_entry sx_store [0:7];
    load_rs_entry sx_load  [0:7];

    always_comb begin
        sx_store = s3_store;
        sx_load  = s3_load;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(sx_store[i].id == 0) continue;
            if(sx_store[i].valid_addr) continue;

            if(str_fwd_vals[0].id != 0 && sx_store[i].id == str_fwd_vals[0].id) begin
                sx_store[i].eff_addr   = str_fwd_vals[0].mem_dest;
                sx_store[i].valid_addr = 1;
                //$display("Store A %d eff_addr received | %t", sx_store[i].id, $time);
            end

            else if(str_fwd_vals[1].id != 0 && sx_store[i].id == str_fwd_vals[1].id) begin
                sx_store[i].eff_addr   = str_fwd_vals[1].mem_dest;
                sx_store[i].valid_addr = 1;
                //$display("Store B %d eff_addr received | %t", sx_store[i].id, $time);
            end
        end
    end
    // 1.E Store to Load Forwarding
    logic [2:0] last_store_idx [0:7]; // per load
    logic has_candidate  [0:7];

    always_comb begin
        for (int i = 0; i < 8; i++) begin
            has_candidate[i] = 0;
            last_store_idx[i] = 0;

            if (sx_load[i].id == 0) continue;
            if (!sx_load[i].valid_addr) continue;

            for (int j = 7; j >= 0; j--) begin
                if (sx_store[j].id == 0) continue;
                if (!sx_store[j].valid_addr) break;

                if (sx_store[j].eff_addr == sx_load[i].eff_addr) begin
                    last_store_idx[i] = j;
                    has_candidate[i] = 1;
                    break;
                end
            end
        end
    end

    store_rs_entry s4_store [0:7];
    load_rs_entry s4_load [0:7];
    
    always_comb begin
        s4_load = sx_load;
        s4_store = sx_store;

        for (int i = 0; i < 8; i++) begin

            if (has_candidate[i]) begin
                s4_load[i].fwd_val = sx_store[last_store_idx[i]].value2;
                s4_load[i].fwd_ready = 1;
            end
        end
    end

    // 1.F Inserting Instructions
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
            end
            29 : begin
                s5_store[s5_store_tail] = instr_a_reg;
                s5_store_count = s5_store_count + 1;
                s5_store_tail = s5_store_tail + 1;
                //$display("Store id %d inserted", instr_a_reg.load_rs.id);
            end
        endcase

        // Inserting instruction B In-Order
        case (instr_b_reg.load_rs.opcode)
            28 : begin
                s5_load[s5_load_tail] = instr_b_reg;
                s5_load[s5_load_tail].count = s5_store_count;
                s5_load_count = s5_load_count + 1;
                s5_load_tail = s5_load_tail + 1;
            end
            29 : begin
                s5_store[s5_store_tail] = instr_b_reg;
                s5_store_count = s5_store_count + 1;
                s5_store_tail = s5_store_tail + 1;
                //$display("Store id %d inserted", instr_b_reg.load_rs.id);
            end
        endcase
    end

    // 1.G Buffer Head Incrementing
    store_rs_entry s6_store [0:7];
    load_rs_entry s6_load  [0:7];
    logic [0:2] s6_store_head, s6_load_head;
    logic [0:2] s6_store_tail, s6_load_tail;
    logic [0:3] s6_store_count, s6_load_count;
    logic done_s, done_l;

    always_comb begin
        s6_store = s5_store;
        s6_load = s5_load;
        s6_store_head = s5_store_head;
        s6_load_head = s5_load_head;
        s6_store_tail = s5_store_tail;
        s6_load_tail = s5_load_tail;
        s6_store_count = s5_store_count;
        s6_load_count = s5_load_count;
        done_s = 0; done_l = 0;

        // Advance store head past zeroed entries
        for(int i = 0; i < RS_SIZE; i++) begin
            if(!done_s) begin
                if(s6_store[s6_store_head].id == 0)
                    s6_store_head = s6_store_head + 1;
                else
                    done_s = 1;
            end
        end

        // Advance load head past zeroed entries
        for(int i = 0; i < RS_SIZE; i++) begin
            if(!done_l) begin
                if(s6_load[s6_load_head].id == 0)
                    s6_load_head = s6_load_head + 1;
                else
                    done_l = 1;
            end
        end
    end

    // Stage 2 - Outputs
    store_rs_entry s7_store [0:7];
    load_rs_entry s7_load  [0:7];

    // 2.A Get indexes of all ready operations (ready stores, ready loads, loads that need eff_addr)
    logic [0:RS_SIZE - 1] store_dispatch_mask;
    logic [0:2] load_disp_imm_idx, load_disp_mem_idx;
    logic valid_disp_imm, valid_disp_mem;
    
    logic [0:RS_SIZE - 1] load_addr_mask;

    always_comb begin
        store_dispatch_mask = '0;
        load_disp_mem_idx = '0;
        load_disp_imm_idx = '0;
        load_addr_mask = '0;
        done_a = 0; done_b = 0;
        done_c = 0; done_d = 0;

        valid_disp_mem = 0; valid_disp_imm = 0;

        s7_store = s6_store;
        s7_load = s6_load;
        
        // Get indexes for ready stores
        for(int i = 0; i < RS_SIZE; i++) begin
            if(s7_store[i].id != 0 && s7_store[i].check1 && s7_store[i].check2 && !s7_store[i].dispatched) begin
                if(!done_a) begin
                    store_dispatch_mask[i] = 1;
                    done_a = 1;
                end else if (!done_b) begin
                    store_dispatch_mask[i] = 1;
                    done_b = 1;
                end
            end
        end

        // Get index for ready memory load
        for(int i = 0; i < RS_SIZE; i++) begin
            if(s7_load[i].valid_addr && s7_load[i].count == 0 && !s7_load[i].dispatched && !valid_disp_mem && !s7_load[i].fwd_ready && !s7_load[i].pending_addr) begin
                load_disp_mem_idx = i;
                valid_disp_mem = 1;
            end
        end

        // Get index for ready immediate load
        for(int i = 0; i < RS_SIZE; i++) begin
            if(s7_load[i].valid_addr && s7_load[i].fwd_ready && !s7_load[i].dispatched && !valid_disp_imm) begin
                load_disp_imm_idx = i;
                valid_disp_imm = 1;
            end
        end

        // Get indexes for loads that can get their eff_addr
        for(int i = 0; i < RS_SIZE; i++) begin
            if(s7_load[i].id != 0 && s7_load[i].base_ready && !s7_load[i].dispatched 
            && !s7_load[i].valid_addr && !s7_load[i].pending_addr) begin
                if(!done_c) begin
                    load_addr_mask[i] = 1;
                    done_c = 1;
                    //$display("Load %d getting forwarded for eff_addr | %t", s7_load[i].id, $time);
                end else if (!done_d) begin
                    load_addr_mask[i] = 1;
                    done_d = 1;
                    //$display("Load %d getting forwarded for eff_addr | %t", s7_load[i].id, $time);
                end
            end
        end
    end

    logic done_store_a, done_store_b, done_store_c, done_store_d;

    // 2.B Assign all outputs
    always_comb begin
        done_store_a = 0; done_store_b = 0;
        done_store_c = 0; done_store_d = 0;
        str_op_a = '0;
        str_op_b = '0;
        load_disp_mem = '0;
        load_disp_imm = '0;
        load_to_fu_a = '0;
        load_to_fu_b = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(store_dispatch_mask[i]) begin
                if(!done_store_a) begin
                    str_op_a = s7_store[i];
                    done_store_a = 1;
                    //$display("Store %d getting forwarded for eff_addr | %t", s7_store[i].id, $time);
                end else if(!done_store_b) begin
                    str_op_b = s7_store[i];
                    done_store_b = 1;
                    //$display("Store %d getting forwarded for eff_addr | %t", s7_store[i].id, $time);
                end
            end
                
            if(load_addr_mask[i]) begin
                if(!done_store_c) begin
                    load_to_fu_a = s7_load[i];
                    done_store_c = 1;
                end else if(!done_store_d) begin
                    load_to_fu_b = s7_load[i];
                    done_store_d = 1;
                end
            end
        end

        if(valid_disp_mem) begin
            load_disp_mem = s7_load[load_disp_mem_idx];
            //$display("Dispatching load %d | %t", s7_load[load_disp_mem_idx].id, $time);
        end

        if(valid_disp_imm) begin
            load_disp_imm = s7_load[load_disp_imm_idx];
            //$display("Dispatching load %d | %t", s7_load[load_disp_mem_idx].id, $time);
        end
    end

    // 2.C Assign all the bits
    store_rs_entry s8_store [0:7];
    load_rs_entry s8_load  [0:7];

    always_comb begin
        s8_store = s7_store;
        s8_load = s7_load;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(store_dispatch_mask[i])
                s8_store[i].dispatched = 1;

            if(load_addr_mask[i])
                s8_load[i].pending_addr = 1;
        end

        if(valid_disp_imm)
            s8_load[load_disp_imm_idx].dispatched = 1;

        if(valid_disp_mem)
            s8_load[load_disp_mem_idx].dispatched = 1;
    end
endmodule