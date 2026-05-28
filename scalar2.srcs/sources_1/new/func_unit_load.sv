`timescale 1ns / 1ps

import config_pkg::*;

// Contains every path for any case of a load
// Load mem will first fetch from memory then dispatch to CDB
// Load imm will immediately dispatch to CDB
// Only doing one of each to mitigate LUT count (idk how big of a difference it makes)
module func_unit_load(
	input logic clk,
	input logic rst,
	input load_fwd_addr load_fwd_a,
	input load_fwd_addr load_fwd_b,
	input load_rs_entry load_mem,
	input load_rs_entry load_imm,

	input logic [DATABUS_WIDTH - 1:0] mem_rd_data,
	output logic [ADDRBUS_SIZE - 1:0] mem_rd_addr,
	
	output load_fwd_addr fwd_addrs [0:1],
	output cdb_entry load_mem_op,
	output cdb_entry load_imm_op
);

	always_ff @ (posedge clk) begin
		if(rst) begin
			fwd_addrs[0] <= '0;
			fwd_addrs[1] <= '0;
		end else begin
			// Could maybe remove the conditional check but can't be too sure
			if(load_fwd_a.valid) begin
				fwd_addrs[0] <= load_fwd_a;
				fwd_addrs[0].eff_addr <= load_fwd_a.base_val + load_fwd_a.offset;
			end else begin
				fwd_addrs[0] <= '0;
			end

			if(load_fwd_b.valid) begin
				fwd_addrs[1] <= load_fwd_b;
				fwd_addrs[1].eff_addr <= load_fwd_b.base_val + load_fwd_b.offset;
			end else begin
				fwd_addrs[1] <= '0;
			end
		end
	end
endmodule
