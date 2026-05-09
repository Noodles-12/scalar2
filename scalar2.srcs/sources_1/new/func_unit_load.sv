`timescale 1ns / 1ps

import config_pkg::*;

// Contains every path for any case of a load
// Load mem will first fetch from memory then dispatch to CDB
// Load imm will immediately dispatch to CDB
// Only doing one of each to mitigate LUT count (idk how big of a difference it makes)
module func_unit_load(clk, rstload_fwd_a, load_fwd_b, load_mem, load_imm,
						fwd_addrs, load_mem_op, load_imm_op);
	input logic clk, rst;
	input load_rs_entry load_fwd_a, load_fwd_b;
    input load_rs_entry load_mem, load_imm;

    output load_fwd_addr fwd_addrs [0:1];
	output cdb_entry load_mem_op, load_imm_op;

	load_rs_entry load_mem_reg, load_imm_reg;

	always_ff @ (posedge clk) begin
		if(rst) begin
			load_mem_reg <= '0;
			load_imm_reg <= '0;
		end else begin
			load_mem_reg <= load_mem;
			load_imm_reg <= load_imm;
		end
	end

    always_comb begin
		fwd_addrs = {default: '0};

		// Taking only last 12 bits of each base register value
		if(load_fwd_a.id != 0) begin
			//$display("Load A to calculate ID: %d", load_fwd_a.id);
			fwd_addrs[0].id = load_fwd_a.id;
        	fwd_addrs[0].eff_addr = load_fwd_a.base_val[24:35] + load_fwd_a.offset;
		end

		if(load_fwd_b.id != 0) begin
			//$display("Load B to calculate ID: %d", load_fwd_b.id);
        	fwd_addrs[1].id = load_fwd_b.id;
        	fwd_addrs[1].eff_addr = load_fwd_b.base_val[24:35] + load_fwd_b.offset;
		end
    end
endmodule
