`timescale 1ns / 1ps

import config_pkg::*;

module instruction_memory (
    input  logic clk,
    input  logic rst,
    input  logic [31:0] ip_addr,

    output logic [31:0] instr_a,
    output logic [31:0] instr_b
);

    (* rom_style = "block" *)
    logic [31:0] mem [0:4095];

    initial begin
        $readmemh("instr_mem.mem", mem);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            instr_a <= '0;
            instr_b <= '0;
        end else begin
            instr_a <= mem[ip_addr[11:0]];
            instr_b <= mem[ip_addr[11:0] + 12'd1];
        end
    end

endmodule