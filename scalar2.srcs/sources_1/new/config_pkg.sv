`timescale 1ns / 1ps

package config_pkg;
    // --- ALU Opcodes ---
    typedef enum logic [5:0] {
        ALU_ADD      = 1,
        ALU_SUB      = 2,
        ALU_LSHIFT   = 3,
        ALU_RSHIFT   = 4,

        ALU_EQ       = 5,
        ALU_GTE      = 6,
        ALU_LTE      = 7,
        ALU_GT       = 8,
        ALU_LT       = 9,

        ALU_AND      = 10,
        ALU_OR       = 11,
        ALU_NOR      = 12,
        ALU_NAND     = 13,
        ALU_XOR      = 14
    } alu_opcode;

    // --- Immediate ALU Opcodes ---
    typedef enum logic [5:0] {
        IALU_ADD     = 15,
        IALU_SUB     = 16,
        IALU_RSHI    = 17,
        IALU_LSHI    = 18,
        IALU_AND     = 19,
        IALU_OR      = 20,
        IALU_EQ      = 21,
        IALU_GTE     = 22,
        IALU_LTE     = 23,
        IALU_GT      = 24,
        IALU_LT      = 25
    } ialu_opcode;

    // --- Comparator Opcodes ---
    typedef enum logic [5:0] {
        COMP_EQ      = 28,
        COMP_NE      = 29,
        COMP_GE      = 30,
        COMP_LT      = 31,
        COMP_LTU     = 32,
        COMP_GEU     = 33
    } comp_opcode;

    typedef enum logic [1:0] {
        NORMAL          = 2'b00,
        JUMP            = 2'b01,
        UNTAKEN_BRANCH  = 2'b10,
        TAKEN_BRANCH    = 2'b11
    } instr_code;

    typedef enum logic [1:0] {
        ROB_REG = 2'b00,
        ROB_STR = 2'b01,
        ROB_BRN = 2'b10
    } rob_t;

    typedef enum logic { 
        COMMIT_GOOD = 1'b0,
        COMMIT_BAD  = 1'b1
    } commit_t;

    // --- Processor Parameters ---
    localparam INSTR_WIDTH      = 32;
    localparam ARCH_REGS_BITS   = 4;
    localparam NUM_ARCH_REGS    = (1 << ARCH_REGS_BITS);
    localparam PHYS_REGS_BITS   = 5;
    localparam NUM_PHYS_REGS    = (1 << PHYS_REGS_BITS);
    localparam DATABUS_WIDTH    = 32;
    localparam ADDRBUS_SIZE     = 12;
    localparam DATA_MEM_SIZE    = 4096;
    localparam CDB_SIZE         = 3;
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
        instr_code code;
    } instruction;

    // Check if I'm even using this
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
        logic [7:0] padding;
    } int_rs_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [5:0] opcode;
        logic [4:0] reg_s;
        logic [31:0] value_s;
        logic check_s;
        logic [11:0] imm;
        logic [4:0] dest;
        logic [33:0] padding;
    } imm_rs_entry;

    // lw: $dest <= data_mem[($reg_s) + offset]
    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [5:0] opcode;
        logic [4:0] reg_s;      // This is the base register 
        logic [31:0] value_s;   // base value to combine with offset for address
        logic check_s;
        logic [11:0] offset;
        logic [4:0] dest;
        logic [3:0] idx_ref; // Represents index of store queue; everything above this is a store before this load
        logic dispatched;
        logic pending_addr;
        logic [27:0] padding;
    } load_rs_entry;

    // sw: data_mem[($reg_d) + offset] <= ($reg_s)
    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [5:0] opcode;
        logic [4:0] reg_s;
        logic [31:0] value_s;
        logic check_s;
        logic [4:0] reg_d;
        logic [31:0] value_d;
        logic check_d;
        logic [11:0] offset;
        logic dispatched;
    } store_rs_entry;

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
        logic [12:0] padding;
    } branch_rs_entry;

    typedef union packed {
        int_rs_entry int_rs;
        imm_rs_entry imm_rs;
        load_rs_entry load_rs;
        store_rs_entry store_rs;
        branch_rs_entry branch_rs;
        logic [100:0] raw;
    } rs_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic done;
        logic [1:0] code;
        logic [31:0] result; // Don't even need this maybe
        logic [4:0] new_prf; // Phys reg to write result into
        logic [4:0] old_prf; // Phys reg to free
        logic [3:0] arch; // Do something with RRT
    } reg_rob_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic done;
        logic [1:0] code;
        logic [31:0] value;
        logic [11:0] mem_dest;
        logic [1:0] padding;
    } str_rob_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic done;
        logic [1:0] code;
        logic [11:0] recov_addr;
        logic [4:0] hist_entry;
        logic predict;
        logic actual;
        logic [26:0] padding;
    } branch_rob_entry;

    typedef union packed {
        reg_rob_entry reg_rob;
        str_rob_entry str_rob;
        branch_rob_entry branch_rob;
        logic [54:0] raw;
    } rob_entry;

    // base_val, offset, & idx used for forwarding mem_dest back into entry
    // mem_dest, id, & value used for ROB
    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [2:0] idx;
        logic [11:0] base_val;
        logic [11:0] offset;
        logic [11:0] mem_dest;
        logic [31:0] value;
    } str_disp_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic result;
    } branch_disp_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [4:0] prf;
        logic [31:0] result;
    } cdb_entry;

    typedef struct packed {
        logic [0:DATABUS_WIDTH-1] write_data;
        logic [ADDRBUS_SIZE-1:0] write_addr;
        logic is_valid;
    } mem_write_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
    } id_to_free;

    typedef struct packed {
        logic valid;
        logic [2:0] idx;
        logic [11:0] offset;
        logic [11:0] base_val;
        logic [11:0] eff_addr;
    } load_fwd_addr;
endpackage
