`timescale 1ns / 1ps

package config_pkg;
    // --- ALU Parameters ---
    localparam ALU_ADD      = 1;
    localparam ALU_SUB      = 2;
    localparam ALU_LSHIFT   = 3;
    localparam ALU_RSHIFT   = 4;

    localparam ALU_EQ       = 5;
    localparam ALU_GTE      = 6;
    localparam ALU_LTE      = 7;
    localparam ALU_GT       = 8;
    localparam ALU_LT       = 9;

    localparam ALU_AND      = 10;
    localparam ALU_OR       = 11;
    localparam ALU_NOR      = 12;
    localparam ALU_NAND     = 13;
    localparam ALU_XOR      = 14;

    // --- Processor Parameters ---
    localparam INSTR_WIDTH      = 32;
    localparam ARCH_REGS_BITS   = 4;
    localparam NUM_ARCH_REGS    = (1 << ARCH_REG_BITS);
    localparam PHYS_REGS_BITS   = 5;
    localparam NUM_PHYS_REGS    = (1 << PHYS_REGS_BITS);
    localparam DATABUS_WIDTH    = 36;
    localparam ADDRBUS_SIZE     = 32;
    localparam DATA_MEM_SIZE    = 4096;
    localparam CDB_SIZE         = 6;
    localparam ALU_RS_SIZE      = 16;
    localparam MEM_RS_SIZE      = 8;
    localparam RS_SIZE          = 8;

    // --- Types ---
    // opcode, reg_d, reg_s, reg_t, imm, pad
    typedef struct packed {
        logic [5:0] opcode;
        logic [3:0] reg_d;
        logic [3:0] reg_s;
        logic [3:0] reg_t;
        logic [11:0] imm;
        logic [1:0]  pad;
    } instruction;

    typedef struct packed {
        logic valid;
        logic [0:DATABUS_WIDTH-1] data;
    } phys_reg;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [5:0] opcode;
        logic [4:0] reg_s;
        logic [31:0] value_s;
        logic check_s;
        logic [4:0] reg_t;
        logic [31:0] value_t;
        logic check_t;
        logic [4:0] dest;
        logic [33:0] padding;
    } int_rs_entry;

    typedef struct packed {
        logic [0:4] id;
        logic [0:5] opcode;
        logic [0:4] reg_s;
        logic [0:35] value;
        logic check;
        logic [0:11] imm;
        logic [0:4] dest;
        logic [0:56] padding;
    } imm_rs_entry;

    // lw: $dest <= data_mem[($reg_s) + offset]
    typedef struct packed {
        logic [0:4] id;
        logic [0:5] opcode;
        logic [0:4] reg_s;
        logic [0:35] base_val;   // value of reg_s for address computation
        logic base_ready;         // base_val is valid
        logic [0:11] offset;
        logic [0:11] eff_addr;
        logic valid_addr;
        logic pending_addr;
        logic [0:4] dest;
        logic [0:3] count; // Represents previous stores before this instruction
        logic dispatched;
        logic [0:35] fwd_val;    // store-forwarded data value
        logic fwd_ready;          // fwd_val is valid; skip memory access
        logic padding;
    } load_rs_entry;

    // sw: data_mem[($reg_d) + offset] <= ($reg_s)
    typedef struct packed {
        logic [0:4] id;
        logic [0:5] opcode;
        logic [0:4] reg_d;
        logic [0:35] value1;
        logic check1;
        logic [0:4] reg_s;
        logic [0:35] value2;
        logic check2;
        logic [0:11] offset;
        logic [0:11] eff_addr;
        logic valid_addr;
        logic dispatched;
        logic [0:5] padding;
    } store_rs_entry;

    typedef union packed {
        int_rs_entry int_rs;
        imm_rs_entry imm_rs;
        load_rs_entry load_rs;
        store_rs_entry store_rs;
        logic [126:0] raw;
    } rs_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic done;
        logic [31:0] result;
        logic [4:0] new_prf;
        logic [4:0] old_prf;
        logic [3:0] arch;
        logic [11:0] mem_dest; // store instruction target address
        logic is_store;
    } rob_entry;

    typedef struct packed {
        logic [0:4] id;
        logic [0:11] mem_dest;
        logic [0:35] value;
    } str_rob_entry;

    typedef struct packed {
        logic [0:4] id;
        logic [0:4] prf;
        logic [0:35] result;
    } cdb_entry;

    typedef struct packed {
        logic [0:DATABUS_WIDTH-1] write_data;
        logic [0:ADDRBUS_SIZE-1] write_addr;
        logic is_valid;
    } mem_write_entry;

    typedef struct packed {
        logic [0:5] id;
        logic [0:DATABUS_WIDTH-1] eff_addr;
    } load_fwd_addr;
endpackage
