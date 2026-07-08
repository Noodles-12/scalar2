`timescale 1ns / 1ps

import config_pkg::*;

module instruction_memory (
    input logic clk,
    input logic rst,
    input logic predict_flush,
    input logic mispredict_flush,
    input logic [ADDRBUS_SIZE-1:0] ip_addr,

    output logic [31:0] instr_a,
    output logic [31:0] instr_b,
    output logic [ADDRBUS_SIZE-1:0] instr_a_addr,
    output logic [ADDRBUS_SIZE-1:0] instr_b_addr
);

    (* ram_style = "distributed" *)
    logic [31:0] mem [0:DATA_MEM_SIZE - 1];

    initial begin
        $readmemh("instr_mem.mem", mem);
    end

    always_ff @(posedge clk) begin
        if(rst || predict_flush || mispredict_flush) begin
            instr_a <= '0;
            instr_b <= '0;
            instr_a_addr <= '0;
            instr_b_addr <= '0;
        end else begin
            instr_a <= mem[ip_addr];
            instr_b <= mem[ip_addr + 1];
            instr_a_addr <= ip_addr;
            instr_b_addr <= ip_addr + 1;
        end
    end

endmodule