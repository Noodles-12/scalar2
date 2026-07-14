`timescale 1ns / 1ps

import config_pkg::*;

module dispatch_pl(
    input logic clk,
    input logic rst,
    input rs_entry rename_a,
    input rs_entry rename_b,
    input rob_entry rob_a,
    input rob_entry rob_b,
    input id_to_free ids_to_free [0:1],
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],

    output rs_entry rs_op_a [0:3],
    output rs_entry rs_op_b [0:3],
    output rob_entry rob_op_a,
    output rob_entry rob_op_b
);

    rs_entry rs_disp_a, rs_disp_b;
    rob_entry rob_disp_a, rob_disp_b;

    logic done_a, done_b;
    logic [4:0] free_a, free_b;

    logic [1:0] code_a, code_b;

    // CDB match signals — instruction A
    logic match_as_i, match_as_j, match_as_k;
    logic match_at_i, match_at_j, match_at_k;

    // CDB match signals — instruction B
    logic match_bs_i, match_bs_j, match_bs_k;
    logic match_bt_i, match_bt_j, match_bt_k;

    // Each entry: 1 = free, 0 = taken
    (* max_fanout = 8 *) logic id_list [0:31];

    always_ff @ (posedge clk) begin
        if (rst) begin
            id_list <= '{default: 1'b1};
            rob_op_a <= '0;
            rob_op_b <= '0;
        end else begin
            for (int i = 0; i < 4; i++) begin
                rs_op_a[i] <= (i == code_a) ? rs_disp_a : '0;
                rs_op_b[i] <= (i == code_b) ? rs_disp_b : '0;
            end

            rob_op_a <= rob_disp_a;
            rob_op_b <= rob_disp_b;

            // Freeing any id of committed instructions
            for(int i = 0; i < 2; i++) begin
                if(ids_to_free[i].valid)
                    id_list[ids_to_free[i].id] <= 1;
            end

            if(done_a && rename_a.int_rs.valid)
                id_list[free_a] <= 0;

            if(done_b && rename_b.int_rs.valid)
                id_list[free_b] <= 0;
        end
    end

    always_comb begin
        done_a = 0; free_a = 0;
        done_b = 0; free_b = 0;

        // Search lower half for free_a
        for (int i = 0; i < 16; i++) begin
            if (id_list[i] && !done_a) begin
                free_a = i;
                done_a = 1;
            end
        end

        // Search upper half for free_b — independent, no dependency on done_a
        for (int i = 16; i < 32; i++) begin
            if (id_list[i] && !done_b) begin
                free_b = i;
                done_b = 1;
            end
        end
    end

    always_comb begin
        rs_disp_a = rename_a;
        rs_disp_b = rename_b;

        rob_disp_a = rob_a;
        rob_disp_b = rob_b;

        match_as_i = 0; match_as_j = 0; match_as_k = 0;
        match_at_i = 0; match_at_j = 0; match_at_k = 0;
        match_bs_i = 0; match_bs_j = 0; match_bs_k = 0;
        match_bt_i = 0; match_bt_j = 0; match_bt_k = 0;

        // Assigning & freeing ids if id was found & instruction is valid
        if(done_a && rename_a.int_rs.valid) begin
            rs_disp_a.int_rs.id = free_a;
            rob_disp_a.reg_rob.id = free_a;
        end

        if(done_b && rename_b.int_rs.valid) begin
            rs_disp_b.int_rs.id = free_b;
            rob_disp_b.reg_rob.id = free_b;
        end

        // ---------------- CDB snoop for instruction A ----------------
        unique case(rs_disp_a.int_rs.opcode) inside
            [1:14], [28:33] : begin
                // primary source = reg_s
                if (!rs_disp_a.int_rs.check_s) begin
                    match_as_i = (rs_disp_a.int_rs.reg_s == cdb_arr[0].prf);
                    match_as_j = (rs_disp_a.int_rs.reg_s == cdb_arr[1].prf);
                    match_as_k = (rs_disp_a.int_rs.reg_s == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_as_i: begin rs_disp_a.int_rs.value_s = cdb_arr[0].result; rs_disp_a.int_rs.check_s = 1'b1; end
                        match_as_j: begin rs_disp_a.int_rs.value_s = cdb_arr[1].result; rs_disp_a.int_rs.check_s = 1'b1; end
                        match_as_k: begin rs_disp_a.int_rs.value_s = cdb_arr[2].result; rs_disp_a.int_rs.check_s = 1'b1; end
                        default: ;
                    endcase
                end

                // secondary source = reg_t
                if (!rs_disp_a.int_rs.check_t) begin
                    match_at_i = (rs_disp_a.int_rs.reg_t == cdb_arr[0].prf);
                    match_at_j = (rs_disp_a.int_rs.reg_t == cdb_arr[1].prf);
                    match_at_k = (rs_disp_a.int_rs.reg_t == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_at_i: begin rs_disp_a.int_rs.value_t = cdb_arr[0].result; rs_disp_a.int_rs.check_t = 1'b1; end
                        match_at_j: begin rs_disp_a.int_rs.value_t = cdb_arr[1].result; rs_disp_a.int_rs.check_t = 1'b1; end
                        match_at_k: begin rs_disp_a.int_rs.value_t = cdb_arr[2].result; rs_disp_a.int_rs.check_t = 1'b1; end
                        default: ;
                    endcase
                end
            end

            [15:25], [26:26] : begin
                // only reg_s exists for imm/load
                if (!rs_disp_a.imm_rs.check_s) begin
                    match_as_i = (rs_disp_a.imm_rs.reg_s == cdb_arr[0].prf);
                    match_as_j = (rs_disp_a.imm_rs.reg_s == cdb_arr[1].prf);
                    match_as_k = (rs_disp_a.imm_rs.reg_s == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_as_i: begin rs_disp_a.imm_rs.value_s = cdb_arr[0].result; rs_disp_a.imm_rs.check_s = 1'b1; end
                        match_as_j: begin rs_disp_a.imm_rs.value_s = cdb_arr[1].result; rs_disp_a.imm_rs.check_s = 1'b1; end
                        match_as_k: begin rs_disp_a.imm_rs.value_s = cdb_arr[2].result; rs_disp_a.imm_rs.check_s = 1'b1; end
                        default: ;
                    endcase
                end
            end

            [27:27] : begin
                // store: reg_d = address base, reg_s = data value
                if (!rs_disp_a.store_rs.check_d) begin
                    match_as_i = (rs_disp_a.store_rs.reg_d == cdb_arr[0].prf);
                    match_as_j = (rs_disp_a.store_rs.reg_d == cdb_arr[1].prf);
                    match_as_k = (rs_disp_a.store_rs.reg_d == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_as_i: begin rs_disp_a.store_rs.value_d = cdb_arr[0].result; rs_disp_a.store_rs.check_d = 1'b1; end
                        match_as_j: begin rs_disp_a.store_rs.value_d = cdb_arr[1].result; rs_disp_a.store_rs.check_d = 1'b1; end
                        match_as_k: begin rs_disp_a.store_rs.value_d = cdb_arr[2].result; rs_disp_a.store_rs.check_d = 1'b1; end
                        default: ;
                    endcase
                end

                if (!rs_disp_a.store_rs.check_s) begin
                    match_at_i = (rs_disp_a.store_rs.reg_s == cdb_arr[0].prf);
                    match_at_j = (rs_disp_a.store_rs.reg_s == cdb_arr[1].prf);
                    match_at_k = (rs_disp_a.store_rs.reg_s == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_at_i: begin rs_disp_a.store_rs.value_s = cdb_arr[0].result; rs_disp_a.store_rs.check_s = 1'b1; end
                        match_at_j: begin rs_disp_a.store_rs.value_s = cdb_arr[1].result; rs_disp_a.store_rs.check_s = 1'b1; end
                        match_at_k: begin rs_disp_a.store_rs.value_s = cdb_arr[2].result; rs_disp_a.store_rs.check_s = 1'b1; end
                        default: ;
                    endcase
                end
            end

            default: ;
        endcase

        // ---------------- CDB snoop for instruction B ----------------
        unique case(rs_disp_b.int_rs.opcode) inside
            [1:14], [28:33] : begin
                if (!rs_disp_b.int_rs.check_s) begin
                    match_bs_i = (rs_disp_b.int_rs.reg_s == cdb_arr[0].prf);
                    match_bs_j = (rs_disp_b.int_rs.reg_s == cdb_arr[1].prf);
                    match_bs_k = (rs_disp_b.int_rs.reg_s == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_bs_i: begin rs_disp_b.int_rs.value_s = cdb_arr[0].result; rs_disp_b.int_rs.check_s = 1'b1; end
                        match_bs_j: begin rs_disp_b.int_rs.value_s = cdb_arr[1].result; rs_disp_b.int_rs.check_s = 1'b1; end
                        match_bs_k: begin rs_disp_b.int_rs.value_s = cdb_arr[2].result; rs_disp_b.int_rs.check_s = 1'b1; end
                        default: ;
                    endcase
                end

                if (!rs_disp_b.int_rs.check_t) begin
                    match_bt_i = (rs_disp_b.int_rs.reg_t == cdb_arr[0].prf);
                    match_bt_j = (rs_disp_b.int_rs.reg_t == cdb_arr[1].prf);
                    match_bt_k = (rs_disp_b.int_rs.reg_t == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_bt_i: begin rs_disp_b.int_rs.value_t = cdb_arr[0].result; rs_disp_b.int_rs.check_t = 1'b1; end
                        match_bt_j: begin rs_disp_b.int_rs.value_t = cdb_arr[1].result; rs_disp_b.int_rs.check_t = 1'b1; end
                        match_bt_k: begin rs_disp_b.int_rs.value_t = cdb_arr[2].result; rs_disp_b.int_rs.check_t = 1'b1; end
                        default: ;
                    endcase
                end
            end

            [15:25], [26:26] : begin
                if (!rs_disp_b.imm_rs.check_s) begin
                    match_bs_i = (rs_disp_b.imm_rs.reg_s == cdb_arr[0].prf);
                    match_bs_j = (rs_disp_b.imm_rs.reg_s == cdb_arr[1].prf);
                    match_bs_k = (rs_disp_b.imm_rs.reg_s == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_bs_i: begin rs_disp_b.imm_rs.value_s = cdb_arr[0].result; rs_disp_b.imm_rs.check_s = 1'b1; end
                        match_bs_j: begin rs_disp_b.imm_rs.value_s = cdb_arr[1].result; rs_disp_b.imm_rs.check_s = 1'b1; end
                        match_bs_k: begin rs_disp_b.imm_rs.value_s = cdb_arr[2].result; rs_disp_b.imm_rs.check_s = 1'b1; end
                        default: ;
                    endcase
                end
            end

            [27:27] : begin
                if (!rs_disp_b.store_rs.check_d) begin
                    match_bs_i = (rs_disp_b.store_rs.reg_d == cdb_arr[0].prf);
                    match_bs_j = (rs_disp_b.store_rs.reg_d == cdb_arr[1].prf);
                    match_bs_k = (rs_disp_b.store_rs.reg_d == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_bs_i: begin rs_disp_b.store_rs.value_d = cdb_arr[0].result; rs_disp_b.store_rs.check_d = 1'b1; end
                        match_bs_j: begin rs_disp_b.store_rs.value_d = cdb_arr[1].result; rs_disp_b.store_rs.check_d = 1'b1; end
                        match_bs_k: begin rs_disp_b.store_rs.value_d = cdb_arr[2].result; rs_disp_b.store_rs.check_d = 1'b1; end
                        default: ;
                    endcase
                end

                if (!rs_disp_b.store_rs.check_s) begin
                    match_bt_i = (rs_disp_b.store_rs.reg_s == cdb_arr[0].prf);
                    match_bt_j = (rs_disp_b.store_rs.reg_s == cdb_arr[1].prf);
                    match_bt_k = (rs_disp_b.store_rs.reg_s == cdb_arr[2].prf);

                    unique case (1'b1)
                        match_bt_i: begin rs_disp_b.store_rs.value_s = cdb_arr[0].result; rs_disp_b.store_rs.check_s = 1'b1; end
                        match_bt_j: begin rs_disp_b.store_rs.value_s = cdb_arr[1].result; rs_disp_b.store_rs.check_s = 1'b1; end
                        match_bt_k: begin rs_disp_b.store_rs.value_s = cdb_arr[2].result; rs_disp_b.store_rs.check_s = 1'b1; end
                        default: ;
                    endcase
                end
            end

            default: ;
        endcase

        // Dispatch Logic
        // Any type of renamed instruction should have id & opcode in same bit positions
        case(rs_disp_a.int_rs.opcode) inside
            [1:14] : code_a = 2'b00;
            [15:25]: code_a = 2'b01;
            [26:27]: code_a = 2'b10;
            [28:33]: code_a = 2'b11;
            default: code_a = 2'b00;
        endcase

        case(rs_disp_b.int_rs.opcode) inside
            [1:14] : code_b = 2'b00;
            [15:25]: code_b = 2'b01;
            [26:27]: code_b = 2'b10;
            [28:33]: code_b = 2'b11;
            default: code_b = 2'b00;
        endcase
    end
endmodule