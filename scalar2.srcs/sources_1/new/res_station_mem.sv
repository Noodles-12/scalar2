`timescale 1ns / 1ps

import config_pkg::*; 

module res_station_mem(
    input logic clk,
    input logic rst,
    input rs_entry instr_a,
    input rs_entry instr_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],
    input logic [5:0] id_to_free [0:1],
    input str_rob_entry str_fwd_vals [0:1],
    input load_fwd_addr load_fwd_addrs [0:1],
    
    output store_rs_entry str_op_a,
    output store_rs_entry str_op_b,


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

    // Stage 1.A Insert input instructions in RS
    store_rs_entry s1_store_buffer [0:7];
    load_rs_entry s1_load_buffer [0:7];
    logic [3:0] s1_store_count, s1_load_count;
    logic [2:0] s1_s_head, s1_s_tail, s1_l_head, s1_l_tail;
    logic s1_valid;

    // Latch 1
    store_rs_entry ff1_store_buffer [0:7];
    load_rs_entry ff1_load_buffer [0:7];
    logic [3:0] ff1_store_count, ff1_load_count;
    logic [2:0] ff1_s_head, ff1_s_tail, ff1_l_head, ff1_l_tail;

    // Stage 2 Dispatch loads with
    store_rs_entry s2_store_buffer [0:7];
    load_rs_entry s2_load_buffer [0:7];

    logic [2:0] load_fwd_idx_a, load_fwd_idx_b;
    logic load_fwd_found_a, load_fwd_found_b;

    load_fwd_addr load_fwd_a, load_fwd_b;
    logic s2_valid;

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
        end else begin
            if(s2_valid) begin
                store_buffer <= s2_store_buffer;
                load_buffer <= s2_load_buffer;

                store_count <= ff1_store_count;
                load_count <= ff1_load_count;

                s_head <= ff1_s_head;
                s_tail <= ff1_s_tail;

                l_head <= ff1_l_head;
                l_tail <= ff1_l_tail;
            end

            load_fwd_a_reg <= load_fwd_a;
            load_fwd_b_reg <= load_fwd_b;
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

        s1_valid = instr_a.load_rs.valid | instr_b.load_rs.valid;

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

    always_ff @ (posedge clk) begin
        if(rst) begin
            ff1_store_buffer <= '{default: '0};
            ff1_load_buffer <= '{default: '0};

            ff1_store_count <= '0;
            ff1_load_count <= '0;

            ff1_s_head <= '0;
            ff1_s_tail <= '0;
            ff1_l_head <= '0;
            ff1_l_tail <= '0;
        end else begin
            if(s1_valid) begin
                ff1_store_buffer <= s1_store_buffer;
                ff1_load_buffer <= s1_load_buffer;

                ff1_store_count <= s1_store_count;
                ff1_load_count <= s1_load_count;

                ff1_s_head <= s1_s_head;
                ff1_s_tail <= s1_s_tail;
                ff1_l_head <= s1_l_head;
                ff1_l_tail <= s1_l_tail;
            end
        end
    end

    // Stage 2
    // Dispatching Loads
    always_comb begin
        s2_store_buffer = ff1_store_buffer;
        s2_load_buffer  = ff1_load_buffer;

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

        s2_valid = load_fwd_found_a | load_fwd_found_b;
    end
endmodule