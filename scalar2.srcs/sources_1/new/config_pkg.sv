`timescale 1ns / 1ps

package config_pkg;
    // --- ALU Parameters ---
    localparam ALU_ADD      = 1;
    localparam ALU_SUB      = 2;
    localparam ALU_LSHIFT   = 3;
    localparam ALU_RSHIFT   = 4;
    localparam ALU_MOD      = 5;

    localparam ALU_EQ       = 6;
    localparam ALU_GTE      = 7;
    localparam ALU_LTE      = 8;
    localparam ALU_GT       = 9;
    localparam ALU_LT       = 10;

    localparam ALU_AND      = 11;
    localparam ALU_OR       = 12;
    localparam ALU_NOR      = 13;
    localparam ALU_NAND     = 14;
    localparam ALU_XOR      = 15;
    
    // --- Processor Parameters ---
    localparam INSTR_WIDTH      = 30;
    localparam NUM_REGS_BITS    = 4;
    localparam NUM_REGS         = (1 << NUM_REGS_BITS);
    localparam DATABUS_WIDTH    = 36;
    localparam ADDRBUS_SIZE     = 12;
    
    // --- Types ---
    typedef struct packed {
            logic [24:29] opcode;
            logic [20:23] reg_d;
            logic [16:19] reg_s;
            logic [12:15] reg_t;
            logic [0:11] imm;
    } instruction;
    
    typedef struct packed {
        logic valid;
        logic free;
        logic [0:DATABUS_WIDTH - 1] data;
    } phys_reg;

    /*
    typedef union packed {
        logic [0:29] raw;
        
        struct packed {
            logic [24:29] opcode;
            logic [20:23] reg_d;
            logic [16:19] reg_s1;
            logic [12:15] reg_s2;
            logic [0:11] unused;
        } r_type;
        
        struct packed {
            logic [24:29] opcode;
            logic [20:23] reg_d;
            logic [16:19] reg_s1;
            logic [12:15] unused;
            logic [0:11] imm;
        } i_type;
    } instruction;
    */
endpackage