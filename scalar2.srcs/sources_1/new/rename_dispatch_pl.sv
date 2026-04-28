`timescale 1ns / 1ps

import config_pkg::*;

module rename_dispatch_pl(clk, rename_a, rename_b, rob_a, rob_b,
                            rs_op_a, rs_op_b, rob_op_a, rob_op_b);
    input clk;
    input rs_entry rename_a, rename_b;
    input rob_entry rob_a, rob_b;

    output rs_entry rs_op_a, rs_op_b;
    output rob_entry rob_op_a, rob_op_b;

    rs_entry rename_a_reg, rename_b_reg;
    rob_entry rob_a_reg, rob_b_reg;
    rs_entry dispatch_a, dispatch_b;        // Intermediate wires since we can't assign to a register in comb

    logic [0:1] code_a, code_b;

    // Each entry contains a boolean whether an id (index) is free (1) or not (0)
    logic id_list [0:63];
    logic next_id_list [0:63];

    dispatch_demux_1x4 dispatch_a(.data(dispatch_a),
                                  .code(code_a),
                                  .op(rs_op_a) );

    dispatch_demux_1x4 dispatch_b(.data(dispatch_b),
                                  .code(code_b),
                                  .op(rs_op_b) );

    initial begin
        for(int i = 0; i < 64; i++) begin
            id_list[i] = 1;
        end
    end

    always_ff @ (posedge clk) begin
        rename_a_reg <= rename_a;
        rename_b_reg <= rename_b;

        rob_a_reg <= rob_a;
        rob_b_reg <= rob_b;

        id_list <= next_id_list;
    end

    always_comb begin
        next_id_list = id_list;

        dispatch_a = rename_a_reg;
        dispatch_b = rename_b_reg;

        rob_op_a = rob_a_reg;
        rob_op_b = rob_b_reg;

         // id field should be in same bits for any type of instruction
        for(int i = 0; i < 64; i++) begin
            if(next_id_list[i] == 1) begin
                dispatch_a.int_rs.id = i;
                rob_a.id = i;
                next_id_list[i] = 0;
                break;
            end
        end

        for(int i = 0; i < 64; i++) begin
            if(next_id_list[i] == 1) begin
                dispatch_b.int_rs.id = i;
                rob_b.id = i;
                next_id_list[i] = 0;
                break;
            end
        end
        // Dispatch Logic
        case(rename_a) inside
            [1:15] : code_a = 0;
            [16:27]: code_a = 1;
            default: code_a = 0;
        endcase

        case(rename_b) inside
            [1:15] : code_b = 0;
            [16:27]: code_b = 1;
            default: code_b = 0;
        endcase;
    end
endmodule
