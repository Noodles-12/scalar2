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
    localparam DATA_MEM_SIZE    = 4096;
    
    // --- Types ---
    // opcode, reg_d, reg_s, reg_t, imm
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
        logic [102:107] id;
        logic [96:101]  opcode;
        logic [91:95]   reg1;
        logic [55:90]   value1;
        logic [54:54]   check1;
        logic [49:53]   reg2;
        logic [13:48]   value2;
        logic [12:12]   check2;
        logic [7:11]    dest;
        logic [0:6]     padding;
    } int_rs_entry;

    typedef struct packed {
        logic [102:107] id;
        logic [96:101]  opcode;
        logic [91:95]   reg_s;
        logic [55:90]   value;
        logic [54:54]   check;
        logic [42:53]   imm;
        logic [37:41]   dest;
        logic [0:36]    padding;
    } imm_rs_entry;

    // lw: $dest <= data_mem[($reg) + offset]
    typedef struct packed {
        logic [102:107] id;
        logic [96:101]  opcode;
        logic [91:95]   reg_s;
        logic [55:90]   value;
        logic [54:54]   check;
        logic [42:53]   offset;
        logic [37:41]   dest;
        logic [33:36]   count; // Represents previous stores before this instruction
        logic [0:32]    padding;
    } load_rs_entry;

    // sw: data_mem[($reg_d) + offset] <= ($reg_s)
    typedef struct packed {
        logic [102:107] id;
        logic [96:101]  opcode;
        logic [91:95]   reg_d;
        logic [55:90]   value1;
        logic [54:54]   check1;
        logic [49:53]   reg_s;
        logic [13:48]   value2;
        logic [12:12]   check2;
        logic [0:11]    offset;
    } store_rs_entry;

    typedef union packed {
        int_rs_entry   int_rs;
        imm_rs_entry   imm_rs;
        load_rs_entry  load_rs;
        store_rs_entry store_rs;
        logic [0:107]  raw;
    } rs_entry;

    typedef struct packed {
        logic [63:68] id;
        logic [62:62] done;
        logic [26:61] result;
        logic [21:25] new_prf;
        logic [16:20] old_prf;
        logic [12:15] arch;
        logic [0:11] mem_dest; // store instruction target address
    } rob_entry;

    typedef struct packed {
        logic [48:53] id;
        logic [36:47] mem_dest;
        logic [0:35] value;
    } str_rob_entry;

    typedef struct packed {
        logic [41:46] id;
        logic [36:40] prf;
        logic [0:35] result;
    } cdb_entry;
endpackage