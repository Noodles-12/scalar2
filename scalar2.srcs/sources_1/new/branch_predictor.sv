`timescale 1ns / 1ps

import config_pkg::*;

module branch_predictor(
    input logic rst,
    input logic clk,
    input logic [11:0] pc,
    input instruction instr_a,
    input instruction instr_b
);

    typedef enum logic [1:0] {
        NORMAL          = 2'b00,
        JUMP            = 2'b01,
        UNTAKEN_BRANCH  = 2'b10,
        TAKEN_BRANCH    = 2'b11
    } instr_code;
    
    logic [1:0] history_table [0:31];
    
    instr_code code_a, code_b;

    always_ff @ (posedge clk) begin
        if(rst) begin
            history_table <= '{default: 2'b10};
        end else begin

        end
    end

    // Instruction A code
    always_comb begin
        case(instr_a.opcode) inside
            [6'b000001:6'b011011] : begin
                code_a = NORMAL;
            end
            
            [6'b011100:6'b100001] : begin
            
            end
            
            [6'b100010:6'b100011] : begin
                code_a = JUMP;
            end
            default: code_a = NORMAL;
        endcase
    end
    
    // Instruction B code
    always_comb begin
        case(instr_b.opcode) inside
            [6'b000001:6'b011011] : begin
                code_b = NORMAL;
            end
            
            [6'b011100:6'b100001] : begin
            
            end
            
            [6'b100010:6'b100011] : begin
                code_b = JUMP;
            end
            default: code_b = NORMAL;
        endcase
    end
endmodule
