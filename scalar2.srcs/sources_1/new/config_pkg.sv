`timescale 1ns / 1ps

package config_pkg;
    // --- ALU parameters ---
    
    localparam ALU_ADD      = 1;
    localparam ALU_SUB      = 2;
    localparam ALU_LSHIFT   = 3;
    localparam ALU_RSHIFT   = 4;
    localparam ALU_MOD      = 5;

    localparam ALU_EQ       = 6;   // A == B
    localparam ALU_GTE      = 7;   // A >= B
    localparam ALU_LTE      = 8;   // A <= B
    localparam ALU_GT       = 9;   // A >  B
    localparam ALU_LT       = 10;  // A <  B

    localparam ALU_AND      = 11;
    localparam ALU_OR       = 12;
    localparam ALU_NOR      = 13;
    localparam ALU_NAND     = 14;
    localparam ALU_XOR      = 16;
    
    // --- 
    localparam INSTR_WIDTH  = 30;
    localparam NUM_REGS_BITS    = 4;
    localparam NUM_REGS     = (1 << NUM_REGS_BITS);
    localparam DATABUS_WIDTH    = 36;
endpackage