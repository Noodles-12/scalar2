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
    output load_rs_entry load_to_fu_a,
    output load_rs_entry load_to_fu_b,
    output load_rs_entry load_disp_mem,
    output load_rs_entry load_disp_imm
);

    rs_entry instr_a_reg, instr_b_reg;

    // Both load & stores can happen out of order
    store_rs_entry store_buffer [0:7];  
    logic [2:0] s_head, s_tail;

    load_rs_entry load_buffer [0:7];
    logic [2:0] l_head, l_tail;
    
    logic [3:0] store_count, load_count;

    logic done_a, done_b, done_c, done_d;
    logic [2:0] idx, real_count;
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
            /* instr_a_reg <= instr_a;
            instr_b_reg <= instr_b;

            store_buffer <= s8_store;
            load_buffer <= s8_load;

            store_count <= s6_store_count;
            load_count <= s6_load_count;

            s_head <= s6_store_head;
            s_tail <= s6_store_tail;

            l_head <= s6_load_head;
            l_tail <= s6_load_tail; */
        end
    end

    // 1.X Insert Entries
    always_comb begin
        /* case(instr_a_regl.load_rs.opcode)
        endcase */
    end
endmodule