`timescale 1ns / 1ps

module res_station_int(clk, instr_a, instr_b);
    logic clk;
    input int_rs_entry instr_a, instr_b;

    int_rs_entry instr_a_reg, instr_b_reg;

    int_rs_entry res_station [0:15];

    logic [0:3] avail_entry_a, avail_entry_b;

    initial begin
        avail_entry_a = 0;
        avail_entry_b = 1;    
    end

    always_ff @ (posedge clk) begin
        instr_a_reg <= instr_a;
        instr_b_reg <= instr_b;
    end


endmodule
