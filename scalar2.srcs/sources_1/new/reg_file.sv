`timescale 1ns / 1ps

// Decode already happens b/c of the struct type fields, so renaming happens in here
module reg_file(clk, og_instr_a, og_instr_b);
    input clk;
    input instruction og_instr_a, og_instr_b;
    
    // Register Alias Table (RAT) - 16 Registers
    // Each register holds the index of a physical register in PRF (0-31)
    logic [0:4] alias_table [0:NUM_REGS - 1];
    
    // Physical Register File (PRF) - 32 Registers
    phys_reg phys_file [0:31];
    
    instruction instr_a_reg, instr_b_reg;

    int_rs_instr int_instr_a, int_instr_b;
    
    initial begin
        // Instantiate PRF
        for(int i = 0; i < 32; i = i + 1) begin
            phys_file[i].valid = 1;
            phys_file[i].free = 1;
            phys_file[i].data = 1;
        end
        
        // Instantiate RAT (as well as taken physical registers)
        for(int i = 0; i < NUM_REGS; i = i + 1) begin
            alias_table[i] = i;
            phys_file[i] = 0;
        end
    end
    
    always_ff @ (posedge clk) begin
        instr_a_reg <= og_instr_a;
        instr_b_reg <= og_instr_b;
    end
    
    always_comb begin
        // Have pointers to next free physical registers

        // Both R-Type Instructions
        if(instr_a_reg.opcode inside {[1:15]} && instr_b_reg inside {[1:15]}) begin
            int_instr_a.opcode = instr_a_reg.opcode;
            int_instr_b.opcode = instr_b_reg.opcode;

            int_instr_a.reg1 = alias_table[instr_a_reg.reg_s];
            int_instr_a.reg2 = alias_table[instr_a_reg.reg_t];
            int_instr_a.value1 = phys_file[int_instr_a.reg_s].data;
            int_instr_a.value2 = phys_file[int_instr_a.reg_t].data;

            
        end
    end
endmodule
