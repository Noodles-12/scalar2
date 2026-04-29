`timescale 1ns / 1ps

module rename_rs_rob_tb();
    // Inputs
    logic clk;
    instruction instr_a, instr_b;

    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b; 

    //rs_entry rs_entry_a [0:3], rs_entry_b [0:3];
    //rob_entry rob_entry_a, rob_entry_b;

    // rob_entry output_rob [0:3];

    // int_rs_entry intrs_op_a, intrs_op_b;

    // logic almost_full_int, almost_full_imm;

    reg_file rf(.clk(clk),
                .og_instr_a(instr_a),
                .og_instr_b(instr_b),
                .rename_a(rename_a),
                .rename_b(rename_b),
                .rob_a(rob_a),
                .rob_b(rob_b) );

    /*
    rename_dispatch_pl dispatch(.clk(clk),
                                .rename_a(rename_a),
                                .rename_b(rename_b),
                                .rob_a(rob_a),
                                .rob_b(rob_b),
                                .rs_op_a(rs_entry_a),
                                .rs_op_b(rs_entry_b),
                                .rob_op_a(rob_entry_a),
                                .rob_op_b(rob_entry_b) );
                                
    reorder_buffer rob(.clk(clk),
                       .input_a(rob_entry_a),
                       .input_b(rob_entry_b),
                       .output_arr(output_rob) );

    res_station_int rs_int(.clk(clk),
                           .instr_a(rs_entry_a[0]),
                           .instr_b(rs_entry_b[0]),
                           .almost_full(almost_full_int),
                           .output_a(intrs_op_a),
                           .output_b(intrs_op_b) );
    */

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        instr_a = 30'b000001_0001_0010_0011_000000000000;                 // add r1, r2, r3
        instr_b = 30'b000011_0100_0001_0110_000000000000; #10; #10; #10;  // sub r4, r1, r3 RAW
        $finish;
    end

endmodule
