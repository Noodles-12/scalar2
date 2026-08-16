`timescale 1ns / 1ps

import config_pkg::*;

module common_data_bus(
    input cdb_entry int_res_a,
    input cdb_entry int_res_b,
    input cdb_entry imm_res_a,
    input cdb_entry imm_res_b,
    input cdb_entry load_res_a,
    input cdb_entry load_res_b,

    output cdb_entry cdb_arr [0:CDB_SIZE - 1]
);
    assign cdb_arr[0] = int_res_a;
    assign cdb_arr[1] = int_res_b;
    assign cdb_arr[2] = imm_res_a;
    assign cdb_arr[3] = imm_res_b;
    assign cdb_arr[4] = load_res_a;
    assign cdb_arr[5] = load_res_b;
endmodule
