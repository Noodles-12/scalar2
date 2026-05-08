## Clock - 25 MHz oscillator on H16
set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 40.000 -waveform {0 4} [get_ports { clk }]

## Reset - BTN0 (D19)
set_property -dict { PACKAGE_PIN D19  IOSTANDARD LVCMOS33 } [get_ports { rst }]

## LEDs - prf_out[0:3] -> LD0..LD3
set_property -dict { PACKAGE_PIN R14  IOSTANDARD LVCMOS33 } [get_ports { prf_out[0] }]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports { prf_out[1] }]
set_property -dict { PACKAGE_PIN N16  IOSTANDARD LVCMOS33 } [get_ports { prf_out[2] }]
set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33 } [get_ports { prf_out[3] }]