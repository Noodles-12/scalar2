`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(
    input logic clk,
    input logic rst,
    input logic mispredict_signal, 
    input rs_entry instr_a,
    input rs_entry instr_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],
    input logic [5:0] id_to_free [0:1],

    input str_disp_entry str_fwd_val,
    input load_fwd_addr load_fwd_ip,
    
    output str_disp_entry str_disp_op,

    output load_fwd_addr load_fwd_op,

    output load_rs_entry load_disp_mem,
    output load_rs_entry load_disp_imm
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

    insert_req insert_a, insert_b;
    rs_entry instr_a_bypassed, instr_b_bypassed;

    logic [3:0] store_count, store_insert, store_dispatch, store_count_comb;
    logic [3:0] load_count, load_insert, load_dispatch;

    logic [11:0] store_eff_addr [0:7];
    logic [0:7] store_valid_addr;

    logic [11:0] load_eff_addr [0:7];
    logic [0:7] load_valid_addr;

    // Store dispatch logics
    logic [7:0] done_stores, store_disp_oh;
    logic [2:0] store_disp_idx;
    logic store_disp_found;

    // Load Forwarding logics
    logic [7:0] loads_to_fwd, load_fwd_oh;
    logic [2:0] load_fwd_idx;
    logic load_fwd_found;

    // Store-to-load forwarding logics
    logic [RS_SIZE-1:0] matching_loads;
    logic [2:0] matching_str_idx [0:RS_SIZE-1];
    logic [3:0] idx;
    logic [3:0] real_count;

    logic [RS_SIZE-1:0] loads_no_deps;

    always_ff @ (posedge clk) begin
        if(rst || mispredict_signal) begin
            store_buffer <= '{default: '0};
            load_buffer <= '{default: '0};

            s_head <= '0;
            s_tail <= '0;

            l_head <= '0;
            l_tail <= '0;

            store_count <= '0;
            load_count <= '0;

            load_fwd_op <= '0;

            str_disp_op <= '0;

            store_eff_addr <= '{default: '0};
            store_valid_addr <= '{default: '0};
        end else begin
            s_tail <= s_tail_comb;
            l_tail <= l_tail_comb;

            store_count <= store_count_comb;

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

            for(int i = 0; i < RS_SIZE; i++) begin
                if(load_buffer[i].valid) begin
                    load_buffer[i].count <= (load_buffer[i].count > store_dispatch) 
                                            ? (load_buffer[i].count - store_dispatch) 
                                            : '0;
                end
            end

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

            if (store_disp_found) begin
                str_disp_op.valid <= 1'b1;
                str_disp_op.id <= store_buffer[store_disp_idx].id;
                str_disp_op.idx <= store_disp_idx;
                str_disp_op.base_val <= store_buffer[store_disp_idx].value_d[11:0];
                str_disp_op.offset <= store_buffer[store_disp_idx].offset;
                str_disp_op.value <= store_buffer[store_disp_idx].value_s;
                str_disp_op.mem_dest <= '0;
                store_buffer[store_disp_idx] <= '0;
            end else begin
                str_disp_op <= '0;
            end

            if (load_fwd_found) begin
                load_fwd_op.valid <= 1'b1;
                load_fwd_op.idx <= load_fwd_idx;
                load_fwd_op.offset <= load_buffer[load_fwd_idx].offset;
                load_fwd_op.base_val <= load_buffer[load_fwd_idx].value_s[11:0];
            end else begin
                load_fwd_op <= '0;
            end

            if (str_fwd_val.valid) begin
                store_eff_addr[str_fwd_val.idx] <= str_fwd_val.mem_dest;
                store_valid_addr[str_fwd_val.idx] <= 1;
            end

            if(load_fwd_ip.valid) begin
                load_eff_addr[load_fwd_ip.idx] <= load_fwd_ip.eff_addr;
                load_valid_addr[load_fwd_ip.idx] <= 1;
            end
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
                insert_a.entry.idx_ref = s_tail_comb;
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
                insert_b.entry.idx_ref = s_tail_comb;
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
        store_dispatch = '0;
        done_stores = '0;
        store_disp_oh = '0;
        store_disp_idx = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            done_stores[i] = store_buffer[i].valid & store_buffer[i].check_s & store_buffer[i].check_d;
        end

        store_disp_oh = (~done_stores + 1'b1) & done_stores;

        for (int i = 0; i < RS_SIZE; i++) begin
            if (store_disp_oh[i]) store_disp_idx |= i;
        end

        store_disp_found = |done_stores;

        if(store_disp_found) begin
            store_dispatch = store_dispatch + 1'b1;
        end
    end

    // Forwarding loads to get their effective addresses
    always_comb begin
        loads_to_fwd = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            loads_to_fwd[i] = load_buffer[i].valid & load_buffer[i].check_s & !load_buffer[i].pending_addr;
        end

        load_fwd_oh = (~loads_to_fwd + 1'b1) & loads_to_fwd;

        for (int i = 0; i < RS_SIZE; i++) begin
            if (load_fwd_oh[i]) load_fwd_idx |= i;
        end

        load_fwd_found = |loads_to_fwd;
    end

    always_comb begin
        store_count_comb = store_count + store_insert - store_dispatch;
        //load_count_comb = load_count + load_insert - load_dispatch;
    end

    always_comb begin
        s_empty = (s_head == s_tail);
        s_full  = (s_head[2:0] == s_tail[2:0]) && (s_head[3] != s_tail[3]);

        l_empty = (l_head == l_tail);
        l_full  = (l_head[2:0] == l_tail[2:0]) && (l_head[3] != l_tail[3]);
    end

    // Store-to-load forwarding logic
    always_comb begin
        matching_loads = '0;
        matching_str_idx = '{default: '0};
        loads_no_deps = '0;
        idx = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(!load_buffer[i].valid) continue;
            if(!load_valid_addr[i]) continue;

            /*
                Compared to previous RTL, this one is much better because we start from the store index that 
                the load entry was given on insert. Guaranteed to go through older stores; no need to check

                Making fervent prayers for even half decent hardware/physical efficiency of this
            */
            idx = load_buffer[i].idx_ref;
            for(int j = 0; j < RS_SIZE; j++) begin
                idx = idx - 1'b1;
                // In case store was dispatched OOO (theoretically shouldn't happen)
                if(!store_buffer[idx[2:0]].valid) begin
                    if(idx == s_head) begin
                        if(!matching_loads[i]) loads_no_deps[i] = 1'b1;
                        break;
                    end
                    continue;
                end

                // Conservative check; if store doesn't have valid address, it can't be a match
                if(!store_valid_addr[idx[2:0]]) break;

                /*
                    This is a check for matching addresses
                    If all other stores checked before were not a match AND had an effective address, then
                        this should be the first store that matches the load's effective address especially
                        since this won't happen if there's an unresolved address
                */
                if(store_eff_addr[idx[2:0]] == load_eff_addr[i]) begin
                    matching_loads[i] = 1'b1;
                    matching_str_idx[i] = idx[2:0];
                    break;
                end

                if(idx == s_head) begin
                    /*
                        If we reach the head of the store queue without finding a match, then we know that all stores before this load
                        have been checked and none of them match. This means that this load is not dependent on
                        any previous store and can be dispatched
                    */
                    if(!matching_loads[i]) begin
                        loads_no_deps[i] = 1'b1;
                    end
                    break;
                end
            end
        end
    end
endmodule