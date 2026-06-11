`timescale 1ns / 1ps

import config_pkg::*;

module rename_dispatch_pl(
    input logic clk,
    input logic rst,
    input rs_entry rename_a,
    input rs_entry rename_b,
    input rob_entry rob_a,
    input rob_entry rob_b,
    input id_to_free ids_to_free [0:1],

    output rs_entry rs_op_a [0:3],
    output rs_entry rs_op_b [0:3],
    output rob_entry rob_op_a,
    output rob_entry rob_op_b
);

    rs_entry rs_disp_a, rs_disp_b;
    rob_entry rob_disp_a, rob_disp_b;

    logic done_a, done_b;
    logic [4:0] free_id_a, free_id_b;

    logic [1:0] code_a, code_b;

    // Each entry: 1 = free, 0 = taken
    logic id_list [0:31];
    logic next_id_list [0:31];

    dispatch_demux_1x4 demux_a(.clk(clk),
                               .rst(rst),
                               .data(rs_disp_a),
                               .code(code_a),
                               .op(rs_op_a) );

    dispatch_demux_1x4 demux_b(.clk(clk),
                               .rst(rst),
                               .data(rs_disp_b),
                               .code(code_b),
                               .op(rs_op_b) );

    always_ff @ (posedge clk) begin
        if (rst) begin
            id_list <= '{default: 1'b1};
            rob_op_a <= '0;
            rob_op_b <= '0;
        end else begin
            id_list <= next_id_list;
            rob_op_a <= rob_disp_a;
            rob_op_b <= rob_disp_b;
        end
    end

    always_comb begin
        next_id_list = id_list;

        rs_disp_a = rename_a;
        rs_disp_b = rename_b;

        rob_disp_a = rob_a;
        rob_disp_b = rob_b;

        done_a = 0; free_id_a = 0;
        done_b = 0; free_id_b = 0;

        // Finding free ids
        for(int i = 0; i < 32; i++) begin
            if(id_list[i] && !done_a) begin
                free_id_a = i;
                done_a = 1;
            end else if (id_list[i] && !done_b) begin
                free_id_b = i;
                done_b = 1;
            end
        end

        // Assigning & freeing ids if id was found & instruction is valid
        if(done_a && rename_a.int_rs.valid) begin
            rs_disp_a.int_rs.id = free_id_a;
            rob_disp_a.id = free_id_a;
            next_id_list[free_id_a] = 0;
        end

        if(done_b && rename_b.int_rs.valid) begin
            rs_disp_b.int_rs.id = free_id_b;
            rob_disp_b.id = free_id_b;
            next_id_list[free_id_b] = 0;
        end

        // Freeing any id of commited instructions
        for(int i = 0; i < 2; i++) begin
            if(!ids_to_free[i].valid) continue;
            next_id_list[ids_to_free[i].id] = 1;
        end

        // Dispatch Logic
        // Any type of renamed instruction should have id & opcode in same bit positions
        case(rs_disp_a.int_rs.opcode) inside
            [1:14] : code_a = 2'b00;
            [15:25]: code_a = 2'b01;
            [26:27]: code_a = 2'b10;
            default: code_a = 2'b00;
        endcase

        case(rs_disp_b.int_rs.opcode) inside
            [1:14] : code_b = 2'b00;
            [15:25]: code_b = 2'b01;
            [26:27]: code_b = 2'b10;
            default: code_b = 2'b00;
        endcase;
    end
endmodule
