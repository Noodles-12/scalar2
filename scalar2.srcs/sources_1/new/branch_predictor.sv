`timescale 1ns / 1ps

import config_pkg::*;

module branch_predictor(
    input logic rst,
    input logic clk,
    input logic [11:0] pc,
    input instruction instr_a,
    input instruction instr_b
);
    logic [1:0] history_table [0:31];

    logic is_branch_a, is_branch_b; // Represents conditional branches
    logic is_jump_a, is_jump_b;     // Represents unconditional branches

    always_ff @ (posedge clk) begin
        if(rst) begin
            history_table <= '{default: 2'b10};
        end else begin

        end
    end

    always_comb begin
        is_branch_a = 0; is_branch_b = 0;
    end
endmodule
