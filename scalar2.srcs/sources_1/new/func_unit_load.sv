`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_load(
	input logic clk,
	input logic rst,
	input logic mispredict_signal,
	input load_fwd_addr load_entry,
	input load_disp_entry load_disp_ip,

	input logic [DATABUS_WIDTH - 1:0] mem_rd_data,
	output logic [ADDRBUS_SIZE - 1:0] mem_rd_addr,
	
	output load_fwd_addr fwd_load_addr,
	output cdb_entry load_cdb
);
	logic load_disp_entry load_disp_reg;

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

	// Stage 1: Get data from memory if necessary
	always_ff @ (posedge clk) begin
		if(rst || mispredict_signal) begin
			mem_rd_addr <= '0;
			load_disp_reg <= '0;
		end else begin
			if(load_disp_ip.valid) begin
				if(load_disp_ip.has_dep) begin
					mem_rd_addr <= load_disp_ip.load_rs.base_val + load_disp_ip.load_rs.offset;
				end else begin
					mem_rd_addr <= '0;
				end
			end else begin
				mem_rd_addr <= '0;
			end

			load_disp_reg <= load_disp_ip;
		end
	end

	// Stage 2: Dispatch to CDB
	always_ff @ (posedge clk) begin
		if(rst || mispredict_signal) begin
			load_cdb <= '0;
		end else begin
			if(load_disp_ip.valid) begin
				load_cdb.valid <= 1'b1;
				load_cdb.id <= load_disp_ip.id;
				if(load_disp_ip.has_dep) begin
					load_cdb.result <= mem_rd_data;
				end else begin
					load_cdb.result <= load_disp_ip.value;
				end
			end else begin
				load_cdb <= '0;
			end
		end
	end

endmodule
