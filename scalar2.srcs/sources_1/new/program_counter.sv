`timescale 1ns / 1ps

import config_pkg::*;

module program_counter(
    input logic clk,
    input logic rst,
    input logic write_enable,
    input logic [ADDRBUS_SIZE-1:0] ip_addr,
    
    output logic [ADDRBUS_SIZE-1:0] op_addr
);

    always_ff @ (posedge clk) begin
        if (rst) begin
            op_addr <= '0;
        end else begin
            if(write_enable) begin
                op_addr <= ip_addr;
            end
        end
    end
endmodule
