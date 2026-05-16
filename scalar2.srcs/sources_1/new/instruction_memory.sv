`timescale 1ns / 1ps

import config_pkg::*;

module instruction_memory(
    input  logic clk,
    input  logic rst,
    input  logic [ADDRBUS_SIZE-1:0] ip_addr,

    output instruction instr_a,
    output instruction instr_b
);

    logic [INSTR_WIDTH-1:0] mem [0:4095];

    initial begin
        $readmemb("instr_mem.mem", mem);
    end

    always_ff @ (posedge clk) begin
        if (rst) begin
            instr_a <= '0;
            instr_b <= '0;
        end else begin
            instr_a <= mem[ip_addr];
            instr_b <= mem[ip_addr + 1];
        end
    end

endmodule