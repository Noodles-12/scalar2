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

    typedef struct packed {
        logic [95:100] id;
        logic [89:94]  opcode;
        logic [84:88]  reg1;
        logic [48:83]  value1;
        logic [47:47]  check1;
        logic [42:46]  reg2;
        logic [6:41]   value2;
        logic [5:5]    check2;
        logic [0:4]    dest;
    } int_rs_entry;

    typedef struct packed {
        logic [95:100] id;
        logic [89:94]  opcode;
        logic [85:88]  reg_s;
        logic [49:84]  value;
        logic [48:48]  check;
        logic [36:47]  imm;
        logic [31:35]  dest;
        logic [0:30]   padding;
    } imm_rs_entry;

    typedef union packed {
        int_rs_entry int_rs;
        imm_rs_entry imm_rs;
        logic [0:100] raw;
    } rs_entry;

    //  --- Rename ID Parameters ---
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