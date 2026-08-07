`timescale 1ns / 1ps

import config_pkg::*;

// Contains every path for any case of a load
// Load mem will first fetch from memory then dispatch to CDB
// Load imm will immediately dispatch to CDB
// Only doing one of each to mitigate LUT count (idk how big of a difference it makes)
module func_unit_load(
	input logic clk,
	input logic rst,
	input logic mispredict_signal,
	input load_fwd_addr load_entry,
	input load_rs_entry load_mem,
	input load_rs_entry load_imm,

	input logic [DATABUS_WIDTH - 1:0] mem_rd_data,
	output logic [ADDRBUS_SIZE - 1:0] mem_rd_addr,
	
	output load_fwd_addr fwd_load_addr,
	output cdb_entry load_mem_op,
	output cdb_entry load_imm_op
);

	always_ff @ (posedge clk) begin
		if(rst || mispredict_signal) begin
			fwd_load_addr <= '0;
		end else begin
			if(load_entry.valid) begin
				fwd_load_addr <= load_entry;
				fwd_load_addr.eff_addr <= load_entry.base_val + load_entry.offset;
			end else begin
				fwd_load_addr <= '0;
			end
		end
	end
endmodule
