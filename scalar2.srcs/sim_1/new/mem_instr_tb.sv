`timescale 1ns / 1ps

import config_pkg::*;

module mem_instr_tb();
    logic clk, rst;
    instruction instr_a, instr_b;

    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b;
    
    rs_entry rs_entry_a [0:3], rs_entry_b [0:3];
    rob_entry rob_entry_a, rob_entry_b;

    store_rs_entry str_a, str_b;
    load_rs_entry load_to_fu_a, load_to_fu_b;

    str_rob_entry str_rob [0:1];
    load_fwd_addr load_fwd_addrs [0:1];

    logic [0:DATABUS_WIDTH - 1] mem_rd_data;
	logic [0:ADDRBUS_SIZE - 1] mem_rd_addr;

    load_rs_entry load_disp_mem, load_disp_imm;
    cdb_entry load_mem_cdb, load_imm_cdb;
    
    rob_entry output_rob [0:3];

    logic [0:5] id_to_free [0:3];

    cdb_entry cdb_arr [0:CDB_SIZE - 1];

    logic [0:3] amount_executed;

    reg_file rf(.clk(clk),
                .rst(rst),
                .og_instr_a(instr_a),
                .og_instr_b(instr_b),
                .cdb_arr(cdb_arr),
                .commit_arr(output_rob),
                .rename_a(rename_a),
                .rename_b(rename_b),
                .rob_a(rob_a),
                .rob_b(rob_b) );

    rename_dispatch_pl rd_pl(.clk(clk),
                             .rst(rst),
                             .rename_a(rename_a),
                             .rename_b(rename_b),
                             .rob_a(rob_a),
                             .rob_b(rob_b),
                             .id_to_free(id_to_free),
                             .rs_op_a(rs_entry_a),
                             .rs_op_b(rs_entry_b),
                             .rob_op_a(rob_entry_a),
                             .rob_op_b(rob_entry_b) );

    reorder_buffer rob(.clk(clk),
                       .rst(rst),
                       .input_a(rob_entry_a),
                       .input_b(rob_entry_b),
                       .cdb_arr(cdb_arr),
                       .str_rob(str_rob),
                       .output_arr(output_rob),
                       .id_to_free(id_to_free),
                       .amount_executed(amount_executed) );

    res_station_mem rs_mem(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_entry_a[2]),
                           .instr_b(rs_entry_b[2]),
                           .cdb_arr(cdb_arr),
                           .id_to_free(id_to_free),
                           .str_fwd_vals(str_rob),
                           .load_fwd_addrs(load_fwd_addrs),
                           .str_op_a(str_a),
                           .str_op_b(str_b),
                           .load_to_fu_a(load_to_fu_a),
                           .load_to_fu_b(load_to_fu_b),
                           .load_disp_mem(load_disp_mem),
                           .load_disp_imm(load_disp_imm) );

    func_unit_str str_fu(.clk(clk),
                         .rst(rst),
                         .str_a(str_a),
                         .str_b(str_b),
                         .str_rob(str_rob) );

    func_unit_load load_fu(.clk(clk),
                           .rst(rst),
                           .load_fwd_a(load_to_fu_a),
                           .load_fwd_b(load_to_fu_b),
                           .load_mem(load_disp_mem),
                           .load_imm(load_disp_imm),
                           .mem_rd_data(mem_rd_data),
                           .fwd_addrs(load_fwd_addrs),
                           .load_mem_op(load_mem_cdb),
                           .load_imm_op(load_imm_cdb),
                           .mem_rd_addr(mem_rd_addr) );

    common_data_bus cdb(.int_a(0),
                        .int_b(0),
                        .imm_a(0),
                        .imm_b(0),
                        .load_a(load_mem_cdb),
                        .load_b(load_imm_cdb),
                        .cdb_arr(cdb_arr) );

    data_memory mem(.clk(clk),
                    .rst(rst),
                    .commit_arr(output_rob), 
                    .read_addr(mem_rd_addr),
                    .read_data(mem_rd_data) );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1;
        #10 rst = 0;

        instr_a = 0; instr_b = 0;

        // --- Store-Forwarding and Memory Load Test ---
        // Instruction encoding (30 bits): opcode[6] | reg_d[4] | reg_s[4] | reg_t[4] | imm[12]
        //   SW (opcode=29): data_mem[reg_d + imm] <- reg_s
        //   LW (opcode=28): reg_d <- data_mem[reg_s + imm]
        //
        // Initial state:
        //   All arch registers R0-R15 = 0.
        //   mem[4]=16, mem[8]=30; all other addresses = 0.
        //   R0 is used as the zero-base register throughout.

        // Cycle 1 — two stores
        // SW1: mem[R0+8]  <- R2 = 0    (addr=8,  data=0)
        // SW2: mem[R0+16] <- R3 = 0    (addr=16, data=0)
        instr_a = 30'b011101_0000_0010_0000_000000001000;
        instr_b = 30'b011101_0000_0011_0000_000000010000;
        #10;

        // Cycle 2 — one forwarded load, one memory load
        // LW1: R1 <- mem[R0+8]   addr=8  matches SW1  -> store-forwarded, R1 = 0
        // LW2: R4 <- mem[R0+4]   addr=4  no match     -> reads mem[4]=16, R4 = 16
        instr_a = 30'b011100_0001_0000_0000_000000001000;
        instr_b = 30'b011100_0100_0000_0000_000000000100;
        #10;

        // Cycle 3 — new store, then a load that forwards across the larger store window
        // SW3: mem[R0+24] <- R5 = 0    (addr=24, data=0)
        // LW3: R6 <- mem[R0+16]  addr=16 matches SW2 (still in flight) -> store-forwarded, R6 = 0
        instr_a = 30'b011101_0000_0101_0000_000000011000;
        instr_b = 30'b011100_0110_0000_0000_000000010000;
        #10;

        instr_a = 0; instr_b = 0;
        #150;

        // -----------------------------------------------------------------------
        // Expected Final Result
        // -----------------------------------------------------------------------
        // Registers:
        //   R1 =  0   LW1 store-forwarded from SW1 (R2=0 written to addr 8)
        //   R4 = 16   LW2 no matching store; reads pre-initialized mem[4]=16
        //   R6 =  0   LW3 store-forwarded from SW2 (R3=0 written to addr 16)
        //   R0,R2,R3,R5 = 0 (unmodified sources / base register)
        //
        // Memory after all stores commit:
        //   mem[4]  = 16  (untouched; no store targets addr 4)
        //   mem[8]  =  0  (SW1 overwrites initial value 30 with R2=0)
        //   mem[16] =  0  (SW2 writes R3=0)
        //   mem[24] =  0  (SW3 writes R5=0)
        //
        // Forwarding path:
        //   LW1: count=2 (SW1,SW2 in flight); eff_addr==SW1.eff_addr -> fwd_val=0, fwd_ready=1
        //   LW2: count=2; no addr match; waits for SW1+SW2 to retire, then dispatches to memory
        //   LW3: count=3 (SW1,SW2,SW3 in flight); eff_addr==SW2.eff_addr -> fwd_val=0, fwd_ready=1
        // -----------------------------------------------------------------------

        $finish;
    end
endmodule
