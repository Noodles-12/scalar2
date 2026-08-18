`timescale 1ns / 1ps

import config_pkg::*;

module res_station_mem(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input logic enable,
    input rs_entry instr_a,
    input rs_entry instr_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],
    input rob_entry free_id_a,
    input rob_entry free_id_b,

    input str_disp_entry str_fwd_val_a,
    input str_disp_entry str_fwd_val_b,
    input load_fwd_addr load_fwd_ip,

    output str_disp_entry str_disp_op_a,
    output str_disp_entry str_disp_op_b,
    output load_fwd_addr load_fwd_op,
    output load_disp_entry load_disp_op_a,
    output load_disp_entry load_disp_op_b,
    output logic almost_full
);

    typedef struct packed {
        logic valid;
        logic is_store;
        logic [4:0] idx;
        rs_entry entry;
    } insert_req;

    // Both load & stores can happen out of order
    store_rs_entry store_buffer [0:7];
    logic [3:0] s_head, s_tail;
    logic [3:0] s_tail_comb;
    logic s_full, s_empty;

    load_rs_entry load_buffer [0:7];
    logic [3:0] l_head, l_tail;
    logic [3:0] l_tail_comb;
    logic l_full, l_empty;

    logic [1:0] s_free_count, l_free_count;
    logic [3:0] s_head_p1, l_head_p1;

    insert_req insert_a, insert_b;
    rs_entry instr_a_bypassed, instr_b_bypassed;

    logic [3:0] store_insert, store_dispatch;
    logic [3:0] load_insert, load_dispatch;

    logic [11:0] store_eff_addr [0:7];
    logic [0:7] store_valid_addr;

    logic [11:0] load_eff_addr [0:7];
    logic [0:7] load_valid_addr;

    // Store dispatch logics
    logic [7:0] done_stores, done_stores_masked;
    logic [7:0] store_disp_oh_a, store_disp_oh_b;
    logic [2:0] store_disp_idx_a, store_disp_idx_b;
    logic store_disp_found_a, store_disp_found_b;

    // Load Forwarding logics
    logic [7:0] loads_to_fwd, load_fwd_oh;
    logic [2:0] load_fwd_idx;
    logic load_fwd_found;

    // Load dispatch logics -- two-wide, mirrors the insert side's onehot_a/onehot_b picker
    logic [RS_SIZE-1:0] done_loads, done_loads_masked;
    logic [RS_SIZE-1:0] load_disp_oh_a, load_disp_oh_b;
    logic [2:0] load_disp_idx_a, load_disp_idx_b;
    logic load_disp_found_a, load_disp_found_b;

    // Store-to-load forwarding logics
    logic [RS_SIZE-1:0] matching_loads;
    logic [2:0] matching_str_idx [0:RS_SIZE-1];
    logic [3:0] idx;
    logic [RS_SIZE-1:0] load_no_deps, load_no_deps_comb;

    always_ff @ (posedge clk) begin
        if(rst || mispredict_signal) begin
            store_buffer <= '{default: '0};
            load_buffer <= '{default: '0};

            s_head <= '0;
            s_tail <= '0;

            l_head <= '0;
            l_tail <= '0;

            load_fwd_op <= '0;

            str_disp_op_a <= '0;
            str_disp_op_b <= '0;

            load_disp_op_a <= '0;
            load_disp_op_b <= '0;

            store_eff_addr <= '{default: '0};
            store_valid_addr <= '{default: '0};
        end else begin
            s_tail <= s_tail_comb;
            l_tail <= l_tail_comb;

            if(insert_a.valid) begin
                if(insert_a.is_store) begin
                    store_buffer[insert_a.idx] <= insert_a.entry;
                end else begin
                    load_buffer[insert_a.idx] <= insert_a.entry;
                end
            end

            if(insert_b.valid) begin
                if(insert_b.is_store) begin
                    store_buffer[insert_b.idx] <= insert_b.entry;
                end else begin
                    load_buffer[insert_b.idx] <= insert_b.entry;
                end
            end

            case (s_free_count)
                2'd0 : ;
                2'd1 : begin
                    store_buffer[s_head[2:0]] <= '0;
                    store_valid_addr[s_head[2:0]] <= 1'b0;
                    store_eff_addr[s_head[2:0]] <= '0;
                    s_head <= s_head + 1'b1;
                end
                2'd2 : begin
                    store_buffer[s_head[2:0]] <= '0;
                    store_valid_addr[s_head[2:0]] <= 1'b0;
                    store_eff_addr[s_head[2:0]] <= '0;

                    store_buffer[s_head_p1[2:0]] <= '0;
                    store_valid_addr[s_head_p1[2:0]] <= 1'b0;
                    store_eff_addr[s_head_p1[2:0]] <= '0;

                    s_head <= s_head + 2'd2;
                end
                default : ;
            endcase

            case (l_free_count)
                2'd0 : ;
                2'd1 : begin
                    load_buffer[l_head[2:0]] <= '0;
                    load_valid_addr[l_head[2:0]] <= 1'b0;
                    load_eff_addr[l_head[2:0]] <= '0;
                    l_head <= l_head + 1'b1;
                end
                2'd2 : begin
                    load_buffer[l_head[2:0]] <= '0;
                    load_valid_addr[l_head[2:0]] <= 1'b0;
                    load_eff_addr[l_head[2:0]] <= '0;

                    load_buffer[l_head_p1[2:0]] <= '0;
                    load_valid_addr[l_head_p1[2:0]] <= 1'b0;
                    load_eff_addr[l_head_p1[2:0]] <= '0;

                    l_head <= l_head + 2'd2;
                end
                default : ;
            endcase

            for(int i = 0; i < CDB_SIZE; i++) begin
                if(!cdb_arr[i].valid) continue;
                for(int j = 0; j < RS_SIZE; j++) begin
                    if(store_buffer[j].valid && !store_buffer[j].check_s && cdb_arr[i].prf == store_buffer[j].reg_s) begin
                        store_buffer[j].value_s <= cdb_arr[i].result;
                        store_buffer[j].check_s <= 1;
                    end

                    if(store_buffer[j].valid && !store_buffer[j].check_d && cdb_arr[i].prf == store_buffer[j].reg_d) begin
                        store_buffer[j].value_d <= cdb_arr[i].result;
                        store_buffer[j].check_d <= 1;
                    end

                    if (load_buffer[j].valid && !load_buffer[j].check_s && cdb_arr[i].prf == load_buffer[j].reg_s) begin
                        load_buffer[j].value_s <= cdb_arr[i].result;
                        load_buffer[j].check_s <= 1;
                    end
                end
            end

            if (store_disp_found_a) begin
                str_disp_op_a.valid <= 1'b1;
                str_disp_op_a.id <= store_buffer[store_disp_idx_a].id;
                str_disp_op_a.idx <= store_disp_idx_a;
                str_disp_op_a.base_val <= store_buffer[store_disp_idx_a].value_d[11:0];
                str_disp_op_a.offset <= store_buffer[store_disp_idx_a].offset;
                str_disp_op_a.value <= store_buffer[store_disp_idx_a].value_s;
                str_disp_op_a.mem_dest <= '0;
                store_buffer[store_disp_idx_a].dispatched <= 1'b1;
            end else begin
                str_disp_op_a <= '0;
            end

            if (store_disp_found_b) begin
                str_disp_op_b.valid <= 1'b1;
                str_disp_op_b.id <= store_buffer[store_disp_idx_b].id;
                str_disp_op_b.idx <= store_disp_idx_b;
                str_disp_op_b.base_val <= store_buffer[store_disp_idx_b].value_d[11:0];
                str_disp_op_b.offset <= store_buffer[store_disp_idx_b].offset;
                str_disp_op_b.value <= store_buffer[store_disp_idx_b].value_s;
                str_disp_op_b.mem_dest <= '0;
                store_buffer[store_disp_idx_b].dispatched <= 1'b1;
            end else begin
                str_disp_op_b <= '0;
            end

            if (load_fwd_found) begin
                load_fwd_op.valid <= 1'b1;
                load_fwd_op.idx <= load_fwd_idx;
                load_fwd_op.offset <= load_buffer[load_fwd_idx].offset;
                load_fwd_op.base_val <= load_buffer[load_fwd_idx].value_s[11:0];
                load_buffer[load_fwd_idx].pending_addr <= 1'b1;
            end else begin
                load_fwd_op <= '0;
            end

            if (str_fwd_val_a.valid) begin
                store_eff_addr[str_fwd_val_a.idx] <= str_fwd_val_a.mem_dest;
                store_valid_addr[str_fwd_val_a.idx] <= 1;
            end

            if (str_fwd_val_b.valid) begin
                store_eff_addr[str_fwd_val_b.idx] <= str_fwd_val_b.mem_dest;
                store_valid_addr[str_fwd_val_b.idx] <= 1;
            end

            if(load_fwd_ip.valid) begin
                load_eff_addr[load_fwd_ip.idx] <= load_fwd_ip.eff_addr;
                load_valid_addr[load_fwd_ip.idx] <= 1;
            end

            if(load_disp_found_a) begin
                if(matching_loads[load_disp_idx_a]) begin
                    load_disp_op_a.valid <= 1'b1;
                    load_disp_op_a.has_dep <= 1'b1;
                    load_disp_op_a.load_rs <= load_buffer[load_disp_idx_a];
                    load_disp_op_a.value <= store_buffer[matching_str_idx[load_disp_idx_a]].value_s;
                    load_buffer[load_disp_idx_a].dispatched <= 1'b1;
                end else begin
                    load_disp_op_a.valid <= 1'b1;
                    load_disp_op_a.has_dep <= 1'b0;
                    load_disp_op_a.load_rs <= load_buffer[load_disp_idx_a];
                    load_disp_op_a.value <= '0;
                    load_buffer[load_disp_idx_a].dispatched <= 1'b1;
                end
            end else begin
                load_disp_op_a <= '0;
            end

            if(load_disp_found_b) begin
                if(matching_loads[load_disp_idx_b]) begin
                    load_disp_op_b.valid <= 1'b1;
                    load_disp_op_b.has_dep <= 1'b1;
                    load_disp_op_b.load_rs <= load_buffer[load_disp_idx_b];
                    load_disp_op_b.value <= store_buffer[matching_str_idx[load_disp_idx_b]].value_s;
                    load_buffer[load_disp_idx_b].dispatched <= 1'b1;
                end else begin
                    load_disp_op_b.valid <= 1'b1;
                    load_disp_op_b.has_dep <= 1'b0;
                    load_disp_op_b.load_rs <= load_buffer[load_disp_idx_b];
                    load_disp_op_b.value <= '0;
                    load_buffer[load_disp_idx_b].dispatched <= 1'b1;
                end
            end else begin
                load_disp_op_b <= '0;
            end

            load_no_deps <= load_no_deps_comb;
        end
    end

    always_comb begin
        load_insert = '0;
        store_insert = '0;

        insert_a = '0;
        insert_b = '0;

        s_tail_comb = s_tail;
        l_tail_comb = l_tail;

        // Snoop the CDB for values arriving the same cycle an instruction is
        // dispatched into this RS, so a producer broadcasting this cycle isn't missed.
        instr_a_bypassed = instr_a;
        instr_b_bypassed = instr_b;

        for (int i = 0; i < CDB_SIZE; i++) begin
            if (!cdb_arr[i].valid) continue;

            if (!instr_a_bypassed.store_rs.check_s && cdb_arr[i].prf == instr_a_bypassed.store_rs.reg_s) begin
                instr_a_bypassed.store_rs.value_s = cdb_arr[i].result;
                instr_a_bypassed.store_rs.check_s = 1'b1;
            end

            if (!instr_a_bypassed.store_rs.check_d && cdb_arr[i].prf == instr_a_bypassed.store_rs.reg_d) begin
                instr_a_bypassed.store_rs.value_d = cdb_arr[i].result;
                instr_a_bypassed.store_rs.check_d = 1'b1;
            end

            if (!instr_b_bypassed.store_rs.check_s && cdb_arr[i].prf == instr_b_bypassed.store_rs.reg_s) begin
                instr_b_bypassed.store_rs.value_s = cdb_arr[i].result;
                instr_b_bypassed.store_rs.check_s = 1'b1;
            end

            if (!instr_b_bypassed.store_rs.check_d && cdb_arr[i].prf == instr_b_bypassed.store_rs.reg_d) begin
                instr_b_bypassed.store_rs.value_d = cdb_arr[i].result;
                instr_b_bypassed.store_rs.check_d = 1'b1;
            end
        end

        unique case(instr_a.load_rs.opcode)
            26 : begin
                load_insert = load_insert + 1'b1;
                insert_a.valid = 1;
                insert_a.is_store = 0;
                insert_a.idx = l_tail_comb[2:0];
                insert_a.entry = instr_a_bypassed;
                insert_a.entry.load_rs.idx_ref = s_tail_comb;
                l_tail_comb = l_tail_comb + 1'b1;
            end
            27 : begin
                store_insert = store_insert + 1'b1;
                insert_a.valid = 1;
                insert_a.is_store = 1;
                insert_a.idx = s_tail_comb[2:0];
                insert_a.entry = instr_a_bypassed;
                s_tail_comb = s_tail_comb + 1'b1;
            end
            default: ;
        endcase

        unique case(instr_b.load_rs.opcode)
            26 : begin
                load_insert = load_insert + 1'b1;
                insert_b.valid = 1;
                insert_b.is_store = 0;
                insert_b.idx = l_tail_comb[2:0];
                insert_b.entry = instr_b_bypassed;
                insert_b.entry.load_rs.idx_ref = s_tail_comb;
                l_tail_comb = l_tail_comb + 1'b1;
            end
            27 : begin
                store_insert = store_insert + 1'b1;
                insert_b.valid = 1;
                insert_b.is_store = 1;
                insert_b.idx = s_tail_comb[2:0];
                insert_b.entry = instr_b_bypassed;
                s_tail_comb = s_tail_comb + 1'b1;
            end
            default: ;
        endcase
    end

    // Finding finished store
    always_comb begin
        done_stores = '0;
        done_stores_masked = '0;
        store_disp_oh_a = '0;
        store_disp_oh_b = '0;
        store_disp_idx_a = '0;
        store_disp_idx_b = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            done_stores[i] = store_buffer[i].valid & store_buffer[i].check_s & store_buffer[i].check_d & !store_buffer[i].dispatched;
        end

        store_disp_oh_a = (~done_stores + 1'b1) & done_stores;

        for (int i = 0; i < RS_SIZE; i++) begin
            if (store_disp_oh_a[i]) store_disp_idx_a |= i;
        end

        store_disp_found_a = |done_stores;

        done_stores_masked = done_stores & (~store_disp_oh_a);
        store_disp_oh_b = (~done_stores_masked + 1'b1) & done_stores_masked;

        for (int i = 0; i < RS_SIZE; i++) begin
            if (store_disp_oh_b[i]) store_disp_idx_b |= i;
        end

        store_disp_found_b = |done_stores_masked;
    end

    // Forwarding loads to get their effective addresses
    always_comb begin
        loads_to_fwd = '0;
        load_fwd_oh = '0;
        load_fwd_idx = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            loads_to_fwd[i] = load_buffer[i].valid & load_buffer[i].check_s & !load_buffer[i].pending_addr;
        end

        load_fwd_oh = (~loads_to_fwd + 1'b1) & loads_to_fwd;

        for (int i = 0; i < RS_SIZE; i++) begin
            if (load_fwd_oh[i]) load_fwd_idx |= i;
        end

        load_fwd_found = |loads_to_fwd;
    end

    // Finding finished loads to dispatch -- two-wide, same onehot-priority-picker
    // pattern as the insert side: first ready entry goes out slot A, second
    // (excluding the first) goes out slot B.
    always_comb begin
        done_loads = '0;
        done_loads_masked = '0;
        load_disp_oh_a = '0;
        load_disp_oh_b = '0;
        load_disp_idx_a = '0;
        load_disp_idx_b = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(load_buffer[i].valid && load_valid_addr[i] && load_no_deps[i] && !load_buffer[i].dispatched) begin
                done_loads[i] = 1'b1;
            end

            // Matching load check also guarantees valid store with valid value_s to use
            if(load_buffer[i].valid  && load_valid_addr[i] && matching_loads[i] && !load_buffer[i].dispatched) begin
                done_loads[i] = 1'b1;
            end
        end

        load_disp_oh_a = (~done_loads + 1'b1) & done_loads;

        for (int i = 0; i < RS_SIZE; i++) begin
            if (load_disp_oh_a[i]) load_disp_idx_a |= i;
        end

        load_disp_found_a = |done_loads;

        done_loads_masked = done_loads & (~load_disp_oh_a);
        load_disp_oh_b = (~done_loads_masked + 1'b1) & done_loads_masked;

        for (int i = 0; i < RS_SIZE; i++) begin
            if (load_disp_oh_b[i]) load_disp_idx_b |= i;
        end

        load_disp_found_b = |done_loads_masked;
    end

    always_comb begin
        s_empty = (s_head == s_tail);
        s_full  = (s_head[2:0] == s_tail[2:0]) && (s_head[3] != s_tail[3]);

        l_empty = (l_head == l_tail);
        l_full  = (l_head[2:0] == l_tail[2:0]) && (l_head[3] != l_tail[3]);

        s_head_p1 = s_head + 1'b1;
        l_head_p1 = l_head + 1'b1;
    end

    always_comb begin
        almost_full = ((s_tail - s_head) >= 4'd6) || ((l_tail - l_head) >= 4'd6);
    end

    always_comb begin
        s_free_count = '0;
        l_free_count = '0;

        for (int i = 0; i < RS_SIZE; i++) begin
            if (store_buffer[i].valid && free_id_a.reg_rob.valid && store_buffer[i].id == free_id_a.reg_rob.id) begin
                s_free_count = s_free_count + 1'b1;
            end
            if (store_buffer[i].valid && free_id_b.reg_rob.valid && store_buffer[i].id == free_id_b.reg_rob.id) begin
                s_free_count = s_free_count + 1'b1;
            end

            if (load_buffer[i].valid && free_id_a.reg_rob.valid && load_buffer[i].id == free_id_a.reg_rob.id) begin
                l_free_count = l_free_count + 1'b1;
            end
            if (load_buffer[i].valid && free_id_b.reg_rob.valid && load_buffer[i].id == free_id_b.reg_rob.id) begin
                l_free_count = l_free_count + 1'b1;
            end
        end
    end

    // Store-to-load forwarding logic
    always_comb begin
        matching_loads = '0;
        matching_str_idx = '{default: '0};
        load_no_deps_comb = '0;
        idx = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(!load_buffer[i].valid) continue;
            if(!load_valid_addr[i]) continue;

            idx = load_buffer[i].idx_ref;

            if(idx == s_head) begin
                load_no_deps_comb[i] = 1'b1;
                continue;
            end

            for(int j = 0; j < RS_SIZE; j++) begin
                idx = idx - 1'b1;
                if(!store_buffer[idx[2:0]].valid) begin
                    if(idx == s_head) begin
                        if(!matching_loads[i]) load_no_deps_comb[i] = 1'b1;
                        break;
                    end
                    continue;
                end

                if(!store_valid_addr[idx[2:0]]) break;

                if((store_eff_addr[idx[2:0]] == load_eff_addr[i]) && store_buffer[idx[2:0]].check_s) begin
                    matching_loads[i] = 1'b1;
                    matching_str_idx[i] = idx[2:0];
                    break;
                end

                if(idx == s_head) begin
                    if(!matching_loads[i]) begin
                        load_no_deps_comb[i] = 1'b1;
                    end
                    break;
                end
            end
        end
    end
endmodule
