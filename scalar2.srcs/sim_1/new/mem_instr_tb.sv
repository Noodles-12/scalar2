`timescale 1ns / 1ps

module mem_instr_tb();
    logic clk, rst;
    instruction instr_a, instr_b;

    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b;
    
    rs_entry rs_entry_a [0:3], rs_entry_b [0:3];
    rob_entry rob_entry_a, rob_entry_b;

    store_rs_entry str_a, str_b;

    str_rob_entry str_rob [0:1];
    
    rob_entry output_rob [0:3];

    logic [0:5] id_to_free [0:3];
    logic [0:5] uncommitted_stores;

    // No CDB yet — stub tied to zero
    cdb_entry cdb_arr [0:3] = '{default: '0};

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
                       .input_a(rob_entry_a),
                       .input_b(rob_entry_b),
                       .cdb_arr(cdb_arr),
                       .str_rob(str_rob),
                       .output_arr(output_rob),
                       .id_to_free(id_to_free),
                       .uncommitted_stores(uncommitted_stores) );

    res_station_mem rs_mem(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_entry_a[2]),
                           .instr_b(rs_entry_b[2]),
                           .cdb_arr(cdb_arr),
                           .uncommitted_stores(uncommitted_stores),
                           .fwd_vals(str_rob),
                           .str_op_a(str_a),
                           .str_op_b(str_b) );

    func_unit_str str_fu(.clk(clk),
                         .rst(rst),
                         .str_a(str_a),
                         .str_b(str_b),
                         .str_rob(str_rob) );

    data_memory mem(.clk(clk),
                    .rst(rst),
                    .commit_arr(output_rob) );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1;
        #10 rst = 0;
        
        instr_b = 0;
        // --- No hazard baseline ---
        // sw $3, 4($2) | lw $1, 4($2)   (Same address)
        instr_a = 30'b011101_0011_0010_0000_000000001000;
        instr_b = 30'b011100_0001_0010_0000_000000000100;
        #10;
        
        instr_a = 0; instr_b = 0;
        #100;
        
        $finish;
    end
endmodule
