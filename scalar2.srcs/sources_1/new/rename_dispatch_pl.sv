`timescale 1ns / 1ps

// Currently using just the renamed int instruction, might use a union
module rename_dispatch_pl(renamed_instr_a, renamed_instr_b, clk);
    input clk;
    input int_rs_entry renamed_instr_a, renamed_instr_b;

    int_rs_entry renamed_instr_a_reg, renamed_instr_b_reg;

    always_ff @ (posedge clk) begin
        renamed_instr_a_reg <= renamed_instr_a;
        renamed_instr_b_reg <= renamed_instr_b;
    end

    always_comb begin
        // Dispatch Logic
        if(renamed_instr_a_reg.opcode inside {[1:15]}) begin
            
        end
    end
endmodule
