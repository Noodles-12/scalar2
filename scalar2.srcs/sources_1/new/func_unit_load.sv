`timescale 1ns / 1ps

import config_pkg::*;

// Contains every path for any case of a load
// Load mem will first fetch from memory then dispatch to CDB
// Load imm will immediately dispatch to CDB
// Only doing one of each to mitigate LUT count (idk how big of a difference it makes)
module func_unit_load(
	input logic clk,
	input logic rst,
	input load_rs_entry load_fwd_a,
	input load_rs_entry load_fwd_b,
	input load_rs_entry load_mem,
	input load_rs_entry load_imm,

	input logic [0:DATABUS_WIDTH - 1] mem_rd_data,
	output logic [0:ADDRBUS_SIZE - 1] mem_rd_addr,
	
	output load_fwd_addr fwd_addrs [0:1],
	output cdb_entry load_mem_op,
	output cdb_entry load_imm_op
);

	load_rs_entry fwd_a_reg, fwd_b_reg;

	load_rs_entry load_mem_reg, load_imm_reg;
	load_rs_entry load_mem_reg2, load_imm_reg2;
	cdb_entry load_mem_cdb, load_imm_cdb;

	always_ff @ (posedge clk) begin
		if(rst) begin
			fwd_a_reg <= '0;
			fwd_b_reg <= '0;
		end else begin
			fwd_a_reg <= load_fwd_a;
			fwd_b_reg <= load_fwd_b;
		end
	end

    always_comb begin
		fwd_addrs = '{default: '0};

		// Taking only last 12 bits of each base register value
		if(fwd_a_reg.id != 0) begin
			fwd_addrs[0].id = fwd_a_reg.id;
        	fwd_addrs[0].eff_addr = fwd_a_reg.base_val[24:35] + fwd_a_reg.offset;
		end

		if(fwd_b_reg.id != 0) begin
        	fwd_addrs[1].id = fwd_b_reg.id;
        	fwd_addrs[1].eff_addr = fwd_b_reg.base_val[24:35] + fwd_b_reg.offset;
		end
    end

	// Stage 1: register inputs
	always_ff @ (posedge clk) begin
		if(rst) begin
			load_mem_reg <= '0;
			load_imm_reg <= '0;
		end else begin

			load_mem_reg <= load_mem;
			load_imm_reg <= load_imm;
		end
	end

	// Stage 2: hold metadata while BRAM produces read data
	always_ff @ (posedge clk) begin
		if(rst) begin
			load_mem_reg2 <= '0;
			load_imm_reg2 <= '0;
		end else begin
			load_mem_reg2 <= load_mem_reg;
			load_imm_reg2 <= load_imm_reg;
		end
	end

	always_comb begin
		load_mem_cdb = '0;
		load_imm_cdb = '0;
		mem_rd_addr = '0;

		// Present address from stage 1 so BRAM data is ready in stage 2
		if(load_mem_reg.id != 0)
			mem_rd_addr = load_mem_reg.eff_addr;

		// Pair stage-2 metadata with the BRAM data now available
		if(load_mem_reg2.id != 0) begin
			load_mem_cdb.id = load_mem_reg2.id;
			load_mem_cdb.prf = load_mem_reg2.dest;
			load_mem_cdb.result = mem_rd_data;
		end

		if(load_imm_reg2.id != 0) begin
			load_imm_cdb.id = load_imm_reg2.id;
			load_imm_cdb.prf = load_imm_reg2.dest;
			load_imm_cdb.result = load_imm_reg2.fwd_val;
		end
	end

	always_ff @ (posedge clk) begin
		if(rst) begin
			load_mem_op <= '0;
			load_imm_op <= '0;
		end else begin
			load_mem_op <= load_mem_cdb;
			load_imm_op <= load_imm_cdb;
		end
	end
endmodule
