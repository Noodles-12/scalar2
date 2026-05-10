`timescale 1ns / 1ps

import config_pkg::*;

module common_data_bus(int_a, int_b, imm_a, imm_b, load_a, load_b,
                        cdb_arr);
    input cdb_entry int_a, int_b, imm_a, imm_b, load_a, load_b;

    output cdb_entry cdb_arr [0:CDB_SIZE - 1];

    assign cdb_arr[0] = int_a;
    assign cdb_arr[1] = int_b;
    assign cdb_arr[2] = imm_a;
    assign cdb_arr[3] = imm_b;
    assign cdb_arr[4] = load_a;
    assign cdb_arr[5] = load_b;
endmodule
