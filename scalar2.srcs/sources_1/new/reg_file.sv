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
    
    initial begin
        // Instantiate PRF
        for(int i = 0; i < 32; i = i + 1) begin
            phys_file[i].valid = 1;
            phys_file[i].data = 1;
        end
        
        // Instantiate RAT
        for(int i = 0; i < NUM_REGS; i = i + 1) begin
            alias_table[i] = i;
        end
    end
    
    always_ff @ (posedge clk) begin
        instr_a_reg <= og_instr_a;
        instr_b_reg <= og_instr_b;
    end
    
    always_comb begin
        
    end
endmodule
