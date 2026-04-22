`timescale 1ns / 1ps

module reg_alias_table();

    // Each register holds the index of a physical register in PRF (0-47)
    logic [0:DATABUS_WIDTH - 1] alias_table [0:NUM_REGS - 1];
    
    
endmodule
