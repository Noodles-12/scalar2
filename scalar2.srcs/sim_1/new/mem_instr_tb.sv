`timescale 1ns / 1ps

module mem_instr_tb();
    logic clk, rst;
    instruction instr_a, instr_b;

    rs_entry rename_a, rename_b;
    rs_entry rs_entry_a [0:3], rs_entry_b [0:3];
    rob_entry rob_a, rob_b;

    rob_entry output_rob [0:3];

    store_rs_entry str_a, str_b;

    reg_file rf(.clk(clk),
                .rst(rst),
                .og_instr_a(instr_a),
                .og_instr_b(instr_b),
                .rename_a(rename_a),
                .rename_b(rename_b) );

    reorder_buffer rob(.clk(clk),
                       .input_a(rob_a),
                       .input_b(rob_b),
                       .output_arr(output_rob) );

    rename_dispatch_pl rd_pl(.clk(clk),
                             .rename_a(rename_a),
                             .rename_b(rename_b),
                             .rs_op_a(rs_entry_a),
                             .rs_op_b(rs_entry_b) );

    res_station_mem rs_mem(.clk(clk),
                           .instr_a(rs_entry_a[2]),
                           .instr_b(rs_entry_b[2]),
                           .str_op_a(str_a),
                           .str_op_b(str_b) );

    func_unit_str str_fu(.clk(clk),
                         .str_a(str_a),
                         .str_b(str_b) );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1;
        #10 rst = 0;

        // --- No hazard baseline ---
        // lw $1, 4($2) | sw $3, 8($2)  (independent regs)
        instr_a = 30'b011100_0001_0010_0000_000000000100;
        instr_b = 30'b011101_0011_0010_0000_000000001000;
        #10;

        // --- RAW hazard ---
        // lw $1, 4($2)      : writes $1
        // lw $3, 0($1)      : reads $1 as base -> depends on instr_a's result
        instr_a = 30'b011100_0001_0010_0000_000000000100;
        instr_b = 30'b011100_0011_0001_0000_000000000000;
        #10;
        
        instr_a = 0; instr_b = 0;
        #50;
        
        $finish;
    end
endmodule
