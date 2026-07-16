`timescale 1ns / 1ps

import config_pkg::*;

module commit_pl(
    input logic clk,
    input logic rst,
    input rob_entry rob_a,
    input rob_entry rob_b,

    output logic mispredict_signal,
    output logic [11:0] mispredict_pc,
    rob_entry commit_a,
    rob_entry commit_b
);
    rob_t rob_type_a, rob_type_b;
    commit_t commit_type_a, commit_type_b;

    always_comb begin
        rob_type_a = rob_a.reg_rob.code;

        if(rob_type_a == ROB_BRN) begin
            if(rob_a.branch_rob.predict != rob_a.branch_rob.actual) begin
                commit_type_a = COMMIT_BAD;
            end
            else begin
                commit_type_a = COMMIT_GOOD;
            end
        end
        else begin
            commit_type_a = COMMIT_GOOD;
        end
    end

    always_comb begin
        rob_type_b = rob_b.reg_rob.code;

        if(rob_type_b == ROB_BRN) begin
            if(rob_b.branch_rob.predict != rob_b.branch_rob.actual) begin
                commit_type_b = COMMIT_BAD;
            end
            else begin
                commit_type_b = COMMIT_GOOD;
            end
        end
        else begin
            commit_type_b = COMMIT_GOOD;
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            mispredict_signal <= 1'b0;
            mispredict_pc <= 12'b0;
            commit_a <= '0;
            commit_b <= '0;
        end else begin
            if(commit_type_a == COMMIT_BAD) begin
                mispredict_signal <= 1'b1;
                mispredict_pc <= rob_a.branch_rob.recov_addr;
                commit_a <= rob_a;
                commit_b <= '0;
            end else if(commit_type_b == COMMIT_BAD) begin
                mispredict_signal <= 1'b1;
                mispredict_pc <= rob_b.branch_rob.recov_addr;
                commit_a <= rob_a;
                commit_b <= rob_b;
            end else begin
                mispredict_signal <= 1'b0;
                mispredict_pc <= 12'b0;
                commit_a <= rob_a;
                commit_b <= rob_b;
            end
        end
    end

endmodule
