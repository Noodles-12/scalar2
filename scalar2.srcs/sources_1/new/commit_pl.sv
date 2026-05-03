`timescale 1ns / 1ps

import config_pkg::*;

module commit_pl(clk, rob_op_arr,
                    final_commit, instr_id_to_pop);
    input logic clk;
    input rob_entry rob_op_arr [0:3];

    output rob_entry final_commit [0:3];
    output logic [0:5] instr_id_to_pop [0:3];

    rob_entry rob_op_reg [0:3];

    always_ff @ (posedge clk) begin
        rob_op_reg <= rob_op_arr;
    end

    always_comb begin
        for(int i = 0; i < 4; i++) begin
            final_commit[i] = rob_op_reg[i];
            instr_id_to_pop[i] = rob_op_reg[i].id;
        end
    end
endmodule
