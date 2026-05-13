`timescale 1ns / 1ps

import config_pkg::*;

// Include boundary check on ip_addr
module instruction_memory(clk, rst, ip_addr, instr_a, instr_b);
    input clk, rst;
    input [0:ADDRBUS_SIZE - 1] ip_addr;
    output instruction instr_a, instr_b;

    (* keep_hierarchy = "yes" *) (* ram_style = "block" *) logic [0:INSTR_WIDTH - 1] memory [0:4095];

    initial begin
        for (int i = 0; i < 4096; i++) begin
            memory[i] = '0;
        end
        $readmemb("instr_mem.mem", memory);
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            instr_a <= '0;
            instr_b <= '0;
        end else begin
            instr_a <= memory[ip_addr];
            instr_b <= memory[ip_addr + 1];

            /* if (memory[ip_addr] != 0)
                $display("[%0t] FETCH A @ PC=%0d | op=%0d rd=%0d rs=%0d rt=%0d imm=%0d",
                    $time, ip_addr,
                    memory[ip_addr][0:5], memory[ip_addr][6:9],
                    memory[ip_addr][10:13], memory[ip_addr][14:17],
                    memory[ip_addr][18:29]);
            if (memory[ip_addr + 1] != 0)
                $display("[%0t] FETCH B @ PC=%0d | op=%0d rd=%0d rs=%0d rt=%0d imm=%0d",
                    $time, ip_addr + 1,
                    memory[ip_addr+1][0:5], memory[ip_addr+1][6:9],
                    memory[ip_addr+1][10:13], memory[ip_addr+1][14:17],
                    memory[ip_addr+1][18:29]); */
        end
    end
endmodule
