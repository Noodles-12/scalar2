# Scalar2

## Overview

Scalar2 is a 9-stage (IF-BP-BF-DC-DI-IS-EX/BC-RO-CO) 2-wide issue and commit superscalar processor implementing out-of-order execution via Tomasulo's algorithm with a Reorder Buffer (ROB), Register Alias Table (RAT), and Physical Register File (PRF).

Key features:
- 2-wide issue and commit, out-of-order execution
- Tomasulo-style scheduling with reservation stations
- Register renaming via RAT/PRF, with a separate Register Retirement Table (RRT) for precise recovery on misprediction
- 6-port common data bus (CDB) broadcast network, sized and tested to sustain full 2-wide throughput
- Hardware store-to-load forwarding, including age tracking between the store and load queues and conservative stalling when an older store's address or value is not yet known
- Dynamic 2-bit branch prediction with misprediction recovery

Scalar2 is verified entirely in simulation. See Performance and Verification below for details and for what that scope does and does not cover.

## Performance

Scalar2 is verified and benchmarked entirely in simulation. The figures below come from the project's own test programs, not a standardized benchmark suite (like the RISC-V-tests compliance benchmarks). They should be read as internal consistency checks and illustrations of measured hazard-handling behavior, not as numbers comparable across projects or to commercial cores.

| Metric | Result |
|---|---|
| Average IPC | 1.25 (2.0 theoretical ceiling for 2-wide issue) |
| Branch prediction accuracy | 80-85% |
| RS/ROB stall rate | 5-10% of cycles |

These numbers are related. Some IPC is lost to branch mispredictions and to stalls, so 1.25 out of a possible 2.0 makes sense given the other two numbers.

### CDB Width Validation

The CDB uses 6 ports. This was tested, not assumed. A 3-port version was run on the same programs and had lower IPC. With 6 ports, results from the ALU, loads, and branches can all be broadcast in the same cycle without waiting.

### Known Limitations Behind These Numbers

- Branch prediction currently uses a 2-bit branch predictor. Utilizing a correlating or tournament predictor would be an upgrade and lead to higher prediction accuracy.
- The physical size of the buffers/queues within the reservation stations and reorder buffer often lead to stalling, so increasing the size of these buffers would prevent stalling.

## Verification

Scalar2 is checked with a set of directed test programs covering:

- Basic instruction execution across all supported opcodes
- Dependency chains at different distances (1, 2, and 3 instructions apart), to exercise different forwarding paths
- Load-use hazards
- Store-to-load forwarding, including cases where an older store's value is not ready yet and the load must wait
- Branches and misprediction recovery
- A simple loop, to check PC and branch target behavior over repeated iterations

Each test's final register and memory state is checked against the expected result for that program.

## Caveats

A few design choices might look odd without context. They are on purpose. Scalar2 began as a class project. Some unconventional naming conventions and structural choices reflect that origin rather than a clean-slate design.

**Memory uses direct addressing, not a stack.** Test programs write to fixed addresses instead of using a stack pointer or calling convention. The project's focus is the out-of-order execution engine (renaming, forwarding, hazard detection), not a full software-facing ISA. Test addresses are chosen on purpose to hit specific hazard cases. This is also a result of initially starting this as a class project 

**Stores write to memory at commit, not when they leave the reservation station.** This means a store only touches memory once it is guaranteed to not be on a mispredicted path. A store on a wrong-path branch never writes memory at all.

**Data memory needs two write ports.** Since commit can retire two instructions per cycle and both can be stores, data memory needs to accept two writes in the same cycle. A normal dual-port memory only supports one read and one write, or two reads, not two writes. Data memory is sized to fit the test programs used, keeping this small rather than adding bank splitting and conflict handling for a larger memory.

## Architecture

This architecture shows the general structure of the design and the overall flow. Each stage is labelled and connections that would make the diagram otherwise super messy have been encoded with a color and pattern that should show up on other modules.

<img width="1753" height="973" alt="image" src="https://github.com/user-attachments/assets/c62944c8-7ee0-4aa4-8416-9b69f8f3ad96" />
