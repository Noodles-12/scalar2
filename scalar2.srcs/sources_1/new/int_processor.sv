`timescale 1ns / 1ps

import config_pkg::*;

module int_processor(clk, rst);
    input logic clk, rst;
  	instruction ip_addr, op_addr;

  	instruction instr_a, instr_b;
  
  	rs_entry rename_a, rename_b;
  	rob_entry rob_a, rob_b;
  
  	rs_entry rs_entry_a [0:3], rs_entry_b [0:3];
  	rob_entry rob_entry_a, rob_entry_b;

	program_counter pc(.clk(clk),
                  	   .write_enable(1),
                  	   .ip_addr(ip_addr),
                  	   .op_addr(op_addr) );

	instruction_memory instr_mem(.clk(clk),
                             .ip_addr(op_addr),
                             .instr_a(instr_a),
                             .instr_b(instr_b) );

 	 reg_file rf(.clk(clk),
                 .rst(rst),
                 .og_instr_a(instr_a),
                 .og_instr_b(instr_b),
                 .cdb_arr(),
                 .commit_arr(),
                 .rename_a(rename_a),
                 .rename_b(rename_b),
                 .rob_a(rob_a),
                 .rob_b(rob_b) );
  
  rename_dispatch_pl dp_pl(.clk(clk),
                           .rename_a(rename_a),
                           .rename_b(rename_b),
                           .rob_a(rob_a),
                           .rob_b(rob_b),
                           .id_to_free(),
                           .rs_op_a(rs_entry_a),
                           .rs_op_b(rs_entry_b),
                           .rob_op_a(rob_entry_a),
                           .rob_op_b(rob_entry_b) );

endmodule
