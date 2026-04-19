`timescale 1ns / 1ps

import config_pkg::*;

// Possibly include addition part?
module program_counter(clk, write_enable, ip_addr, op_addr);
    input [0:ADDRBUS_SIZE - 1] ip_addr;
    input clk, write_enable;

    output logic [0:ADDRBUS_SIZE - 1] op_addr;
    
    logic [0:ADDRBUS_SIZE - 1] reg_addr;

    assign op_addr = reg_addr;

    always_ff @ (posedge clk) begin
        reg_addr <= (write_enable == 1) ? ip_addr : 0;
    end
endmodule
