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
    input load_fwd_addr load_fwd_addrs [0:1],
    
    output str_disp_entry str_disp_op,

    output load_fwd_addr load_fwd_a_reg,
    output load_fwd_addr load_fwd_b_reg,

    output load_rs_entry load_disp_mem,
    output load_rs_entry load_disp_imm
);

    typedef struct packed {
        logic valid;
        logic is_store;
        logic [4:0] idx;
        store_rs_entry entry;
    } insert_req;

    // Both load & stores can happen out of order
    store_rs_entry store_buffer [0:7];
    logic [7:0] done_stores, store_disp_oh;
    logic [2:0] store_disp_idx;
    logic store_disp_found;

    logic [2:0] s_head, s_tail;
    logic [2:0] s_tail_comb;

    insert_req insert_a, insert_b;

    load_rs_entry load_buffer [0:7];
    logic [2:0] l_head, l_tail;
    logic [2:0] l_tail_comb;

    logic [3:0] store_count, store_insert, store_dispatch;
    logic [3:0] load_count, load_insert, load_dispatch;

    logic [11:0] store_eff_addr [0:7];
    logic [0:7] store_valid_addr;

    logic [11:0] load_eff_addr [0:7];
    logic [0:7] load_valid_addr;

    // Store-to-load forwarding logic
    logic [RS_SIZE-1:0] matching_loads;
    logic [2:0] matching_str_idx [0:RS_SIZE-1];
    logic [2:0] idx;
    logic [3:0] real_count;

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

            load_fwd_a_reg <= '0;
            load_fwd_b_reg <= '0;

            str_disp_op <= '0;

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
            end else begin
                str_disp_op <= '0;
            end

            if (str_fwd_val.valid) begin
                store_eff_addr[str_fwd_val.idx] <= str_fwd_val.mem_dest;
                store_valid_addr[str_fwd_val.idx] <= 1;
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

        unique case(instr_a.load_rs.opcode)
            26 : begin
                load_insert = load_insert + 1'b1;
                insert_a.valid = 1;
                insert_a.is_store = 0;
                insert_a.idx = l_tail_comb;
                insert_a.entry = instr_a;
                l_tail_comb = l_tail_comb + 1'b1;
            end
            27 : begin
                store_insert = store_insert + 1'b1;
                insert_a.valid = 1;
                insert_a.is_store = 1;
                insert_a.idx = s_tail_comb;
                insert_a.entry = instr_a;
                s_tail_comb = s_tail_comb + 1'b1;
            end
            default: ;
        endcase

        unique case(instr_b.load_rs.opcode)
            26 : begin
                load_insert = load_insert + 1'b1;
                insert_b.valid = 1;
                insert_b.is_store = 0;
                insert_b.idx = l_tail_comb;
                insert_b.entry = instr_b;
                l_tail_comb = l_tail_comb + 1'b1;
            end
            27 : begin
                store_insert = store_insert + 1'b1;
                insert_b.valid = 1;
                insert_b.is_store = 1;
                insert_b.idx = s_tail_comb;
                insert_b.entry = instr_b;
                s_tail_comb = s_tail_comb + 1'b1;
            end
            default: ;
        endcase
    end

    // Finding finished store
    always_comb begin
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
    end

    // Store-to-load forwarding logic
    always_comb begin

    end
    /* 
    // Stage 2
    // Dispatching Loads
    always_comb begin
        s2_store_buffer = s1_store_buffer;
        s2_load_buffer  = s1_load_buffer;

        load_fwd_found_a = 0; load_fwd_idx_a = '0;
        load_fwd_found_b = 0; load_fwd_idx_b = '0;

        load_fwd_a = '0; load_fwd_b = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(s2_load_buffer[i].check_s && !s2_load_buffer[i].pending_addr) begin
                if(!load_fwd_found_a) begin
                    load_fwd_idx_a = i;
                    load_fwd_found_a = 1;
                end else if(!load_fwd_found_b) begin
                    load_fwd_idx_b = i;
                    load_fwd_found_b = 1;
                end
            end
        end

        if(load_fwd_found_a) begin
            load_fwd_a.valid = 1;
            load_fwd_a.idx = load_fwd_idx_a;
            load_fwd_a.offset = s2_load_buffer[load_fwd_idx_a].offset;
            load_fwd_a.base_val = s2_load_buffer[load_fwd_idx_a].value_s[11:0];
            s2_load_buffer[load_fwd_idx_a].pending_addr = 1;
        end

        if(load_fwd_found_b) begin
            load_fwd_b.valid = 1;
            load_fwd_b.idx = load_fwd_idx_b;
            load_fwd_b.offset = s2_load_buffer[load_fwd_idx_b].offset;
            load_fwd_b.base_val = s2_load_buffer[load_fwd_idx_b].value_s[11:0];
            s2_load_buffer[load_fwd_idx_b].pending_addr = 1;
        end
    end

    // Stage 3
    // Dispatching stores
    always_comb begin
        s3_store_buffer = s2_store_buffer;
        s3_load_buffer = s2_load_buffer;

        str_disp_idx_a = '0; str_disp_found_a = 0;
        str_disp_idx_b = '0; str_disp_found_b = 0;
        str_disp_a = '0; str_disp_b = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(!s3_store_buffer[i].valid) continue;

            // Maybe need a valid check
            if(s3_store_buffer[i].check_s && s3_store_buffer[i].check_d 
            && !s3_store_buffer[i].dispatched) begin
                if(!str_disp_found_a) begin
                    str_disp_idx_a = i;
                    str_disp_found_a = 1;
                end else if (!str_disp_found_b) begin
                    str_disp_idx_b = i;
                    str_disp_found_b = 1;
                end
            end
        end

        if(str_disp_found_a) begin
            str_disp_a.valid = 1;
            str_disp_a.id = s3_store_buffer[str_disp_idx_a].id;
            str_disp_a.idx = str_disp_idx_a;
            str_disp_a.base_val = s3_store_buffer[str_disp_idx_a].value_d;
            str_disp_a.offset = s3_store_buffer[str_disp_idx_a].offset;
            str_disp_a.value = s3_store_buffer[str_disp_idx_a].value_s;
            s3_store_buffer[str_disp_idx_a].dispatched = 1;
        end

        if(str_disp_found_b) begin
            str_disp_b.valid = 1;
            str_disp_b.id = s3_store_buffer[str_disp_idx_b].id;
            str_disp_b.idx = str_disp_idx_b;
            str_disp_b.base_val = s3_store_buffer[str_disp_idx_b].value_d;
            str_disp_b.offset = s3_store_buffer[str_disp_idx_b].offset;
            str_disp_b.value = s3_store_buffer[str_disp_idx_b].value_s;
            s3_store_buffer[str_disp_idx_b].dispatched = 1;
        end
    end

    // Stage 4
    // Get forwarded addresses from stores
    always_comb begin
        s4_store_eff_addr = store_eff_addr;
        s4_store_valid_addr = store_valid_addr;

        s4_load_eff_addr = load_eff_addr;
        s4_load_valid_addr = load_valid_addr;

        if(str_fwd_vals[0].valid) begin
            s4_store_eff_addr[str_fwd_vals[0].idx] = str_fwd_vals[0].mem_dest;
            s4_store_valid_addr[str_fwd_vals[0].idx] = 1;
        end

        if(str_fwd_vals[1].valid) begin
            s4_store_eff_addr[str_fwd_vals[1].idx] = str_fwd_vals[1].mem_dest;
            s4_store_valid_addr[str_fwd_vals[1].idx] = 1;
        end

        if(load_fwd_addrs[0].valid) begin
            s4_load_eff_addr[load_fwd_addrs[0].idx] = load_fwd_addrs[0].eff_addr;
            s4_load_valid_addr[load_fwd_addrs[0].idx] = 1;
        end

        if(load_fwd_addrs[1].valid) begin
            s4_load_eff_addr[load_fwd_addrs[1].idx] = load_fwd_addrs[1].eff_addr;
            s4_load_valid_addr[load_fwd_addrs[1].idx] = 1;
        end
    end */
endmodule