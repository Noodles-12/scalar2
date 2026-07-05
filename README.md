# Scalar2
A 2-wide superscalar out-of-order CPU implemented in SystemVerilog, targeting the Arty Z7-20 FPGA at 100MHz.

## Overview
Scalar2 is a 2-wide issue and commit superscalar processor implementing out-of-order execution via Tomasulo's algorithm with a Reorder Buffer (ROB), Register Alias Table (RAT), and Physical Register File (PRF).

## Current Status
- [x] ALU integer and immediate instructions
- [ ] Branch prediction and control flow (in progress)
- [ ] Load/store memory instructions (functionally done; need to optimize)

## Architecture (In Progress)
<img width="1492" height="964" alt="image" src="https://github.com/user-attachments/assets/b6ee63d0-536d-42e8-938c-e81d40da3a01" />
