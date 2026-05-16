`timescale 1ns / 1ps

import config_pkg::*;

// Possibly include addition part?
module program_counter(
    input logic clk,
    input logic write_enable,
    input logic [ADDRBUS_SIZE-1:0] ip_addr,
    
    output logic [ADDRBUS_SIZE-1:0] op_addr
);
    
    logic [ADDRBUS_SIZE-1:0] reg_addr;

    assign op_addr = reg_addr;

    always_ff @ (posedge clk) begin
        reg_addr <= (write_enable == 1) ? ip_addr : 0;
    end
endmodule
