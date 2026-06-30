`timescale 1ns / 1ps

import config_pkg::*;

module instruction_memory (
    input logic clk,
    input logic [ADDRBUS_SIZE-1:0] ip_addr,

    output logic [31:0] instr_a,
    output logic [31:0] instr_b
);

    (* rom_style = "block" *)
    logic [31:0] mem [0:4095];

    logic [31:0] instr_a_r, instr_b_r;

    initial begin
        $readmemh("instr_mem.mem", mem);
    end

    // Cycle N: BRAM read; no reset, allows output register merging
    always_ff @(posedge clk) begin
        instr_a_r <= mem[{ip_addr[ADDRBUS_SIZE - 1:1], 1'b0}];
        instr_b_r <= mem[{ip_addr[ADDRBUS_SIZE - 1:1], 1'b1}];
    end

    // Cycle N+1: second register stage; cuts BRAM output off critical path
    always_ff @(posedge clk) begin
        instr_a <= instr_a_r;
        instr_b <= instr_b_r;
    end

endmodule