`timescale 1ns / 1ps

import config_pkg::*;

module fetch_decode_pl(clk, instr_a, instr_b, instr_op_a, instr_op_b);
    input clk;
    input [0:INSTR_WIDTH - 1] instr_a, instr_b;
    
    output logic [0:INSTR_WIDTH-1] instr_op_a [0:7], instr_op_b [0:7];
    
    
endmodule
