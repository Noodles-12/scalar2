`timescale 1ns / 1ps

import config_pkg::*;

module branch_predictor(
    input logic rst,
    input logic clk,
    input logic [11:0] pc,
    input instruction instr_a,
    input logic [11:0] addr_a,
    input instruction instr_b,
    input logic [11:0] addr_b,
    
    output instruction instr_a_op,
    output instruction instr_b_op,
    output logic [11:0] addr_a_op,
    output logic [11:0] addr_b_op
);
    
    logic [1:0] history_table [0:31];
    
    instr_code code_a, code_b;
    logic [1:0] predict_a, predict_b;
    logic instruction mod_instr_a, mod_instr_b;

    always_ff @ (posedge clk) begin
        if(rst) begin
            history_table <= '{default: 2'b10};
        end else begin
            instr_a_op <= mod_instr_a;
            instr_b_op <= mod_instr_b;

            addr_a_op <= addr_a;
            addr_b_op <= addr_b;
        end
    end

    // Instruction A code
    always_comb begin
        predict_a = history_table[instr_a.imm];

        case(instr_a.opcode) inside
            [6'b000001:6'b011011] : begin
                code_a = NORMAL;
            end
            
            [6'b011100:6'b100001] : begin
                if(predict_a > 2'b01) begin
                    code_a = TAKEN_BRANCH;
                end else begin
                    code_a = UNTAKEN_BRANCH;
                end
            end
            
            [6'b100010:6'b100011] : begin
                code_a = JUMP;
            end
            default: code_a = NORMAL;
        endcase

        mod_instr_a = instr_a;
        mod_instr_a.code = code_a;
    end
    
    // Instruction B code
    always_comb begin
        predict_b = history_table[instr_b.imm];

        case(instr_b.opcode) inside
            [6'b000001:6'b011011] : begin
                code_b = NORMAL;
            end
            
            [6'b011100:6'b100001] : begin
                if(predict_b > 2'b01) begin
                    code_b = TAKEN_BRANCH;
                end else begin
                    code_b = UNTAKEN_BRANCH;
                end
            end
            
            [6'b100010:6'b100011] : begin
                code_b = JUMP;
            end
            default: code_b = NORMAL;
        endcase

        mod_instr_b = instr_b;
        mod_instr_b.code = code_b;
    end
endmodule
