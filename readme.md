# Single-Cycle RISC-V (RV32I) Processor

A clean, hardware-level implementation of a 32-bit single-cycle RISC-V (`RV32I`) processor. Every instruction goes through all five execution steps—from fetching the instruction to writing back the result—within a single clock cycle.

---

## Overview

In a single-cycle design, one clock pulse handles the entire lifecycle of an instruction. While this means the clock period has to be long enough to accommodate the slowest instruction (usually a memory load like `lw`), the hardware datapath is straightforward, predictable, and easy to trace without pipeline hazards or forwarding logic.

### How Each Clock Cycle Works
1. **Instruction Fetch (IF):** The Program Counter (`PC`) points to the current instruction address in Instruction Memory and increments by `4` (`PC + 4`) for the next cycle.
2. **Instruction Decode (ID):** The 32-bit instruction is split into its fields (`opcode`, `rd`, `funct3`, `rs1`, `rs2`, `funct7`, and immediate values). Source registers are read from the Register File, and the Control Unit sets up the datapath flags.
3. **Execute (EX):** The Arithmetic Logic Unit (`ALU`) performs math, logic, address calculation, or branch comparison based on the `ALUOp` and function fields.
4. **Memory Access (MEM):** For load (`lw`) and store (`sw`) instructions, Data Memory is either read from or written to using the address calculated by the ALU.
5. **Write Back (WB):** The final result—coming from the ALU, Data Memory, or `PC + 4`—is saved back into the destination register (`rd`).

---

## Supported Instruction Formats (RV32I)

| Format | Example Instructions | Primary Purpose |
| :--- | :--- | :--- |
| **R-Type** | `add`, `sub`, `and`, `or`, `xor`, `slt`, `sll`, `srl`, `sra` | Register-to-register arithmetic and logic |
| **I-Type** | `addi`, `andi`, `ori`, `lw`, `jalr` | Immediate operations, memory loads, and indirect jumps |
| **S-Type** | `sw`, `sh`, `sb` | Storing register values into Data Memory |
| **B-Type** | `beq`, `bne`, `blt`, `bge` | Conditional branching based on register comparisons |
| **U-Type** | `lui`, `auipc` | Loading upper 20-bit immediates and PC-relative addressing |
| **J-Type** | `jal` | Unconditional jumps with return address linking |

---

## Architecture & Key Modules

* **`pc.v` (Program Counter):** Holds the current 32-bit instruction address and updates on the rising edge of the clock.
* **`imem.v` (Instruction Memory):** Read-only memory preloaded with machine code (`.hex` or `.mem` file).
* **`control_unit.v` (Main Decoder):** Inspects the 7-bit `opcode` to drive datapath signals (`RegWrite`, `ALUSrc`, `MemRead`, `MemWrite`, `Branch`, `Jump`, `MemtoReg`, and `ALUOp`).
* **`alu_control.v` (ALU Decoder):** Combines `ALUOp` with `funct3` and `funct7` to generate the exact 4-bit operation code for the ALU.
* **`reg_file.v` (Register File):** Contains 32 general-purpose 32-bit registers (`x0`–`x31`), with `x0` hardwired to `0`.
* **`imm_gen.v` (Immediate Generator):** Extracts and sign-extends immediate fields for `I`, `S`, `B`, `U`, and `J` instruction types.
* **`alu.v` (Arithmetic Logic Unit):** Executes arithmetic/bitwise operations and outputs a `Zero` flag for branch decisions.
* **`dmem.v` (Data Memory):** Read/write RAM used during load and store instructions.

---

## Repository Structure

```text
├── src/
│   ├── top_riscv.v        # Top-level module connecting datapath & control
│   ├── control_unit.v     # Main instruction decoder
│   ├── alu_control.v      # Secondary ALU operation decoder
│   ├── alu.v              # 32-bit ALU
│   ├── reg_file.v         # 32x32 Register File
│   ├── imm_gen.v          # Sign-extension unit
│   ├── pc.v               # Program Counter
│   ├── imem.v             # Instruction Memory
│   └── dmem.v             # Data Memory
├── tb/
│   └── riscv_tb.v         # Testbench for waveform & register verification
├── programs/
│   └── test_program.hex   # Sample RV32I machine code
└── README.md
```

---

## Getting Started

### Prerequisites
* **Verilog Simulator:** Icarus Verilog (`iverilog`), ModelSim, Verilator, or Vivado
* **Waveform Viewer:** GTKWave (optional, for inspecting internal signals)

### Running the Simulation (Icarus Verilog)
1. **Compile the design and testbench:**
   ```bash
   iverilog -o riscv_sim src/*.v tb/riscv_tb.v
   ```
2. **Run the simulation:**
   ```bash
   vvp riscv_sim
   ```
3. **View waveforms (if `$dumpfile` is enabled in the testbench):**
   ```bash
   gtkwave dump.vcd
   ```

---

## Design Trade-offs

* **Pros:** Simple control logic, no data or control hazards, easy to verify cycle-by-cycle.
* **Cons:** Low maximum clock frequency because the critical path spans the entire datapath in a single cycle; hardware units (like adders and memories) sit idle during parts of the cycle.

---

## License

This project is open-source and available under the [MIT License](LICENSE).