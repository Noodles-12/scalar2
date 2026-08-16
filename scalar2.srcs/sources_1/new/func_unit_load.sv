`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_load(
	input logic clk,
	input logic rst,
	input logic mispredict_signal,
	input load_fwd_addr load_entry,
	input load_disp_entry load_disp_ip_a,
	input load_disp_entry load_disp_ip_b,

	input logic [DATABUS_WIDTH - 1:0] mem_rd_data_a,
	input logic [DATABUS_WIDTH - 1:0] mem_rd_data_b,
	output logic [ADDRBUS_SIZE - 1:0] mem_rd_addr_a,
	output logic [ADDRBUS_SIZE - 1:0] mem_rd_addr_b,

	output load_fwd_addr fwd_load_addr,
	output cdb_entry load_cdb_a,
	output cdb_entry load_cdb_b
);

	load_disp_entry load_disp_reg_a, load_disp_reg2_a;
	load_disp_entry load_disp_reg_b, load_disp_reg2_b;

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
			mem_rd_addr_a <= '0;
			load_disp_reg_a <= '0;
		end else begin
			if(load_disp_ip_a.valid) begin
				if(!load_disp_ip_a.has_dep) begin
					mem_rd_addr_a <= load_disp_ip_a.load_rs.value_s[11:0] + load_disp_ip_a.load_rs.offset;
				end else begin
					mem_rd_addr_a <= '0;
				end
			end else begin
				mem_rd_addr_a <= '0;
			end

			load_disp_reg_a <= load_disp_ip_a;
		end
	end

	always_ff @ (posedge clk) begin
		if(rst || mispredict_signal) begin
			mem_rd_addr_b <= '0;
			load_disp_reg_b <= '0;
		end else begin
			if(load_disp_ip_b.valid) begin
				if(!load_disp_ip_b.has_dep) begin
					mem_rd_addr_b <= load_disp_ip_b.load_rs.value_s[11:0] + load_disp_ip_b.load_rs.offset;
				end else begin
					mem_rd_addr_b <= '0;
				end
			end else begin
				mem_rd_addr_b <= '0;
			end

			load_disp_reg_b <= load_disp_ip_b;
		end
	end

	always_ff @ (posedge clk) begin
		if(rst || mispredict_signal) begin
			load_disp_reg2_a <= '0;
		end else begin
			load_disp_reg2_a <= load_disp_reg_a;
		end
	end

	always_ff @ (posedge clk) begin
		if(rst || mispredict_signal) begin
			load_disp_reg2_b <= '0;
		end else begin
			load_disp_reg2_b <= load_disp_reg_b;
		end
	end

	// Stage 2: Dispatch to CDB
	always_ff @ (posedge clk) begin
		if(rst || mispredict_signal) begin
			load_cdb_a <= '0;
		end else begin
			if(load_disp_reg2_a.valid) begin
				load_cdb_a.valid <= 1'b1;
				load_cdb_a.id <= load_disp_reg2_a.load_rs.id;
				load_cdb_a.prf <= load_disp_reg2_a.load_rs.dest;
				if(!load_disp_reg2_a.has_dep) begin
					load_cdb_a.result <= mem_rd_data_a;
				end else begin
					load_cdb_a.result <= load_disp_reg2_a.value;
				end
			end else begin
				load_cdb_a <= '0;
			end
		end
	end

	always_ff @ (posedge clk) begin
		if(rst || mispredict_signal) begin
			load_cdb_b <= '0;
		end else begin
			if(load_disp_reg2_b.valid) begin
				load_cdb_b.valid <= 1'b1;
				load_cdb_b.id <= load_disp_reg2_b.load_rs.id;
				load_cdb_b.prf <= load_disp_reg2_b.load_rs.dest;
				if(!load_disp_reg2_b.has_dep) begin
					load_cdb_b.result <= mem_rd_data_b;
				end else begin
					load_cdb_b.result <= load_disp_reg2_b.value;
				end
			end else begin
				load_cdb_b <= '0;
			end
		end
	end

endmodule
