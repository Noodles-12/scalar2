`timescale 1ns / 1ps

import config_pkg::*;

module commit_pl(
    input logic clk,
    input logic rst,
    input rob_entry rob_a,
    input rob_entry rob_b,

    output logic mispredict_signal,
    output logic [11:0] mispredict_pc
);
    rob_t rob_type_a, rob_type_b;
    commit_t commit_type_a, commit_type_b;

    always_comb begin
        rob_type_a = rob_a.reg_rob.code;

        if(rob_type_a == ROB_BRN) begin
            if(rob_a.branch_rob.predict != rob_a.branch_rob.actual) begin
                commit_type_a = COMMIT_MISP;
            end
            else begin
                commit_type_a = COMMIT_PRED;
            end
        end
        else begin
            commit_type_a = COMMIT_NORM;
        end
    end

    always_comb begin
        rob_type_b = rob_b.reg_rob.code;

        if(rob_type_b == ROB_BRN) begin
            if(rob_b.branch_rob.predict != rob_b.branch_rob.actual) begin
                commit_type_b = COMMIT_MISP;
            end
            else begin
                commit_type_b = COMMIT_PRED;
            end
        end
        else begin
            commit_type_b = COMMIT_NORM;
        end
    end

endmodule
