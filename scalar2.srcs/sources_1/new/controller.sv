`timescale 1ns / 1ps

import config_pkg::*;

module controller(
    input instr_code code_a,
    input instr_code code_b,
    input logic [11:0] addr_a,
    input logic [11:0] addr_b,
    input logic [11:0] curr_pc,

    output logic predict_flush,
    output logic mispredict_flush,
    output logic [11:0] next_pc
);


endmodule
