`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(
    input logic clk,
    input logic rst,
    input rs_entry instr_a,
    input rs_entry instr_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],
    input logic [5:0] id_to_free [0:1],
    input str_disp_entry str_fwd_vals [0:1],
    input load_fwd_addr load_fwd_addrs [0:1],
    
    output str_disp_entry str_disp_a_reg,
    output str_disp_entry str_disp_b_reg,

    output load_fwd_addr load_fwd_a_reg,
    output load_fwd_addr load_fwd_b_reg,

    output load_rs_entry load_disp_mem,
    output load_rs_entry load_disp_imm
);

    // Both load & stores can happen out of order
    store_rs_entry store_buffer [0:7];  
    logic [2:0] s_head, s_tail;

    load_rs_entry load_buffer [0:7];
    logic [2:0] l_head, l_tail;
    logic [3:0] store_count, load_count;

    logic [11:0] store_eff_addr [0:7];
    logic store_valid_addr [0:7];

    // Stage 1 Insert input instructions in RS
    store_rs_entry s1_store_buffer [0:7];
    load_rs_entry s1_load_buffer [0:7];
    logic [3:0] s1_store_count, s1_load_count;
    logic [2:0] s1_s_head, s1_s_tail, s1_l_head, s1_l_tail;

    // Stage 2 Dispatch loads 
    store_rs_entry s2_store_buffer [0:7];
    load_rs_entry s2_load_buffer [0:7];

    logic [2:0] load_fwd_idx_a, load_fwd_idx_b;
    logic load_fwd_found_a, load_fwd_found_b;
    load_fwd_addr load_fwd_a, load_fwd_b;

    // Stage 3 Dispatch ready stores
    store_rs_entry s3_store_buffer [0:7];
    load_rs_entry s3_load_buffer [0:7];

    logic [2:0] str_disp_idx_a, str_disp_idx_b;
    logic str_disp_found_a, str_disp_found_b;
    str_disp_entry str_disp_a, str_disp_b;

    // Stage 4 Get forwarded store & load eddresses
    logic [11:0] s4_store_eff_addr [0:7];
    logic s4_store_valid_addr [0:7];

    // Stage 0 - Get inputs
    always_ff @ (posedge clk) begin
        if(rst) begin
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

            str_disp_a_reg <= '0;
            str_disp_b_reg <= '0;

            store_eff_addr <= '{default: '0};
            store_valid_addr <= '{default: '0};
        end else begin
            store_buffer <= s3_store_buffer;
            load_buffer <= s3_load_buffer;

            store_count <= s1_store_count;
            load_count <= s1_load_count;

            s_head <= s1_s_head;
            s_tail <= s1_s_tail;

            l_head <= s1_l_head;
            l_tail <= s1_l_tail;

            load_fwd_a_reg <= load_fwd_a;
            load_fwd_b_reg <= load_fwd_b;

            str_disp_a_reg <= str_disp_a;
            str_disp_b_reg <= str_disp_b;

            store_eff_addr <= s4_store_eff_addr;
            store_valid_addr <= s4_store_valid_addr;
        end
    end

    // 1 Insert Entries
    always_comb begin
        s1_store_buffer = store_buffer;
        s1_load_buffer = load_buffer;
        s1_store_count = store_count;
        s1_load_count = load_count;

        s1_s_head = s_head; s1_s_tail = s_tail;
        s1_l_head = l_head; s1_l_tail = l_tail;

        case(instr_a.load_rs.opcode) 
            26 : begin
                s1_load_buffer[s1_l_tail] = instr_a;
                s1_load_buffer[s1_l_tail].count = s1_store_count;
                s1_load_count = s1_load_count + 1;
                s1_l_tail = s1_l_tail + 1;
            end
            27 : begin
                s1_store_buffer[s1_s_tail] = instr_a;
                s1_store_count = s1_store_count + 1;
                s1_s_tail = s1_s_tail + 1;
            end
        endcase

        case(instr_b.load_rs.opcode)
            26 : begin
                s1_load_buffer[s1_l_tail] = instr_b;
                s1_load_buffer[s1_l_tail].count = s1_store_count;
                s1_load_count = s1_load_count + 1;
                s1_l_tail = s1_l_tail + 1;
            end
            27 : begin
                s1_store_buffer[s1_s_tail] = instr_b;
                s1_store_count = s1_store_count + 1;
                s1_s_tail = s1_s_tail + 1;
            end
        endcase
    end

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
    always_comb begin
        s4_store_eff_addr = store_eff_addr;
        s4_store_valid_addr = store_valid_addr;

        if(str_fwd_vals[0].valid) begin
            s4_store_eff_addr[str_fwd_vals[0].idx] = str_fwd_vals[0].mem_dest;
            s4_store_valid_addr[str_fwd_vals[0].idx] = 1;
        end

        if(str_fwd_vals[1].valid) begin
            s4_store_eff_addr[str_fwd_vals[1].idx] = str_fwd_vals[1].mem_dest;
            s4_store_valid_addr[str_fwd_vals[1].idx] = 1;
        end
    end
endmodule