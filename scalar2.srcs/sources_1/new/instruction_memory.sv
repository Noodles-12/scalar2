`timescale 1ns / 1ps

import config_pkg::*;

// Include boundary check on ip_addr
module instruction_memory(clk, ip_addr, instr_a, instr_b);
    input clk;
    input [0:ADDRBUS_SIZE - 1] ip_addr;
    output instruction instr_a, instr_b;

    logic [0:INSTR_WIDTH - 1] memory [0:4095];

    always_ff @ (posedge clk) begin
        instr_a = memory[ip_addr];
        instr_b = memory[ip_addr + 1];
    end
    
    initial begin
        memory[0] = 30'h00000001;
        memory[1] = 30'h00000002;
        memory[2] = 30'h00000003;
        memory[3] = 30'h00000004;
        memory[4] = 30'h00000005;
        memory[5] = 30'h00000006;
        memory[6] = 30'h00000007;
        memory[7] = 30'h00000008;
    end
endmodule
