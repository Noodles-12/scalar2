`timescale 1ns / 1ps

module phys_reg_file();
    typedef struct packed {
        logic valid;
        logic [0:DATABUS_WIDTH - 1] data;
    } reg_entry;
    
    reg_entry reg_file [0:31];
    
    
endmodule
