# 3-Stage 32-bit MIPS Processor with SIMON 32/64 Encryption

A secure, low-power 32-bit MIPS pipelined processor implemented in Verilog, featuring hardware-level SIMON 32/64 encryption/decryption on all memory operations. Designed for IoT edge devices, health sensor nodes, and smart metering applications requiring secure, real-time data processing.

---

## Features

- 3-stage pipeline: IF, EX, MEM/WB
- SIMON 32/64 hardware encryption on every `sw` (store)
- SIMON 32/64 hardware decryption on every `lw` (load)
- Clock gating on data memory for low-power operation
- Input isolation power gating on SIMON modules
- Forwarding unit for MEM→EX data hazard resolution
- Load-use hazard detection with 1-cycle stall
- Branch and jump resolution with pipeline flush
- Internal register file forwarding for same-cycle read/write

---

## Pipeline Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│   IF STAGE      │     │   EX STAGE       │     │   MEM/WB STAGE      │
│                 │     │                  │     │                     │
│  PC             │     │  Register File   │     │  Data Memory        │
│  Instr Memory   │────▶│  ALU             │────▶│  SIMON Decrypt      │
│  Control Unit   │     │  SIMON Encrypt   │     │  Write-Back MUX     │
│  Hazard Unit    │     │  Forwarding Unit │     │  Branch/Jump Resolve│
└─────────────────┘     └──────────────────┘     └─────────────────────┘
         │                       │                          │
    IF/EX Register          EX/MEM Register           Result Out
```

---

## Module Descriptions

### `mips_top`
Top-level module connecting all pipeline stages.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `reset` | Input | 1 | Active-high synchronous reset |
| `result_out` | Output | 32 | Write-back result output |

**Parameter:** `SIMON_KEY = 64'h1918111009080100` — 64-bit hardware encryption key

---

### `pc` — Program Counter
Holds and updates the current instruction address.
- Stalls (holds value) when `stall=1` (load-use hazard)
- Resets to 0 on `reset=1`
- Updates to `pc_next` on every rising clock edge otherwise

---

### `instruction_memory` — Instruction Memory
256 × 32-bit read-only memory storing the program.
- Addressed by `addr[9:2]` (word-aligned)
- Combinational read (no clock needed)

---

### `control` — Control Unit
Decodes the 6-bit opcode and generates all pipeline control signals.

| Signal | Function |
|--------|----------|
| `ALUOp[1:0]` | ALU operation type: `00`=add, `01`=sub, `10`=R-type |
| `ALUSrc` | `0`=register, `1`=immediate as ALU second operand |
| `RegDst` | `0`=rt (I-type dest), `1`=rd (R-type dest) |
| `RegWrite` | Enable write to register file |
| `MemRead` | Enable data memory read + SIMON decrypt |
| `MemWrite` | Enable data memory write + SIMON encrypt |
| `MemtoReg` | `0`=ALU result to reg, `1`=memory data to reg |
| `Branch` | Enable branch address computation |
| `Jump` | Override PC with jump target |

---

### `hazard_unit` — Hazard Detection Unit
Detects load-use data hazards and generates a 1-cycle stall.

**Condition:**
```
load_use_hazard = EX_MemRead AND (EX_write_reg == IF_rs OR EX_write_reg == IF_rt)
```
When asserted: PC is frozen, IF/EX register is flushed (NOP bubble inserted).

---

### `register_file` — 32×32 Register File
- 32 general-purpose 32-bit registers
- `$0` is hardwired to 0
- Internal forwarding: if reading and writing the same register in the same cycle, returns the new write value immediately

---

### `forwarding_unit` — Data Forwarding Unit
Resolves MEM→EX data hazards by bypassing the register file.

| `fwd_A/fwd_B` | Source |
|---------------|--------|
| `2'b00` | Register file (no hazard) |
| `2'b01` | MEM stage ALU result |
| `2'b10` | MEM stage write-back data (lw result) |

---

### `alu_control` — ALU Control
Generates 4-bit ALU control from `ALUOp` and `funct` field.

| Operation | ALUControl |
|-----------|------------|
| AND | `0000` |
| OR | `0001` |
| ADD | `0010` |
| SUB | `0110` |
| SLT | `0111` |

---

### `alu` — 32-bit ALU
Supports: AND, OR, ADD, SUB, SLT. Generates `zero` flag for branch resolution.

---

### `simon_encrypt` — SIMON 32/64 Encryption
- 32-round Feistel network on 32-bit plaintext with 64-bit key
- Activated only when `EX_MemWrite=1` (power gated via input isolation)
- Encrypts store data before writing to data memory
- **Zero pipeline cycle overhead** — runs in parallel with EX stage

---

### `simon_decrypt` — SIMON 32/64 Decryption
- Reverse 32-round Feistel network
- Activated only when `MEM_MemRead=1` (power gated via input isolation)
- Decrypts data after reading from memory, before write-back
- Transparent to software — no extra instructions needed

---

### `simon_keyschedule` — Key Schedule
Expands 64-bit key into 32 × 16-bit round keys using the SIMON Z0 sequence.
`SIMON_KEY = 64'h1918111009080100`

---

### `data_memory` — Data Memory
- 256 × 32-bit word-addressable memory
- Addressed by `addr[9:2]`
- Clock-gated: only receives clock when `MemRead OR MemWrite` is asserted

---

### `clock_gate` — Clock Gating Cell
Latch-based clock gate. Enables `gated_clk` only when `en=1`, eliminating dynamic power on idle memory and SIMON modules.

```
gated_clk = clk AND en_latched
```

---

## Supported Instructions

| Instruction | Type | Opcode/Funct | Operation |
|-------------|------|--------------|-----------|
| `add` | R | funct=`100000` | `rd = rs + rt` |
| `sub` | R | funct=`100010` | `rd = rs - rt` |
| `and` | R | funct=`100100` | `rd = rs & rt` |
| `or` | R | funct=`100101` | `rd = rs \| rt` |
| `slt` | R | funct=`101010` | `rd = (rs < rt) ? 1 : 0` |
| `addi` | I | `001000` | `rt = rs + imm` |
| `lw` | I | `100011` | `rt = Memory[rs+imm]` (decrypted) |
| `sw` | I | `101011` | `Memory[rs+imm] = rt` (encrypted) |
| `beq` | I | `000100` | `if rs==rt: PC = PC+4+imm<<2` |
| `j` | J | `000010` | `PC = {PC[31:28], target, 00}` |
| `nop` | — | `00000000` | No operation |

---

## Test Program (Instruction Memory)

```verilog
memory[0]  = 32'h20080005; // addi $8,  $0,  5      | $8  = 5
memory[1]  = 32'h2009000A; // addi $9,  $0,  10     | $9  = 10
memory[2]  = 32'h200D0000; // addi $13, $0,  0      | $13 = 0 (loop counter)

// LOOP START (jump target = address 3)
memory[3]  = 32'h216D0001; // addi $13, $13, 1      | $13++ (loop counter)
memory[4]  = 32'h01095020; // add  $10, $8,  $9     | $10 = $8 + $9
memory[5]  = 32'hAC0A0000; // sw   $10, 0($0)       | mem[0] = SIMON_encrypt($10)
memory[6]  = 32'h8C0B0000; // lw   $11, 0($0)       | $11 = SIMON_decrypt(mem[0])
memory[7]  = 32'h116A0001; // beq  $11, $10, +1     | if $11==$10, skip next
memory[8]  = 32'h200C0001; // addi $12, $0,  1      | $12 = 1 (error flag)
memory[9]  = 32'h01286022; // sub  $12, $9,  $8     | $12 = $9 - $8 (large - small)
memory[10] = 32'h01094022; // sub  $8,  $8,  $9     | $8  = $8 - $9 (small - large)
memory[11] = 32'h08000003; // j    3                | jump back to LOOP START
memory[12] = 32'h00000000; // nop  (flush slot 1)
memory[13] = 32'h00000000; // nop  (flush slot 2)
```

### Expected Register Values Per Loop Iteration

| Loop | `$8` | `$9` | `$10` | `$11` | `$12` | `$13` |
|------|------|------|-------|-------|-------|-------|
| 1 | −5 | 10 | 15 | 15 | 5 | 1 |
| 2 | −15 | 10 | 5 | 5 | 15 | 2 |
| 3 | −25 | 10 | −5 | −5 | 25 | 3 |

`$13` increments by 1 each iteration — use it in simulation to verify jump is looping correctly.

---

## Power Analysis (Vivado Implementation)

| Component | Power | Share |
|-----------|-------|-------|
| Total On-Chip | **0.139 W** | 100% |
| Dynamic | 0.067 W | 48% |
| — Signals | 0.034 W | 51% of dynamic |
| — Logic | 0.025 W | 37% of dynamic |
| — I/O | 0.008 W | 11% of dynamic |
| — Clocks | <0.001 W | 1% of dynamic |
| Device Static | 0.072 W | 52% |

**Junction Temperature:** 25.7°C (59.3°C thermal margin remaining)

---

## Security

- **Algorithm:** SIMON 32/64 (NSA lightweight block cipher)
- **Key size:** 64-bit
- **Block size:** 32-bit
- **Rounds:** 32
- **Key:** Hardware-provisioned at synthesis time (`SIMON_KEY` parameter)
- **Threat model:** Plaintext never stored in data memory — all stored values are SIMON ciphertext
- **Overhead:** Zero software cycles — encryption/decryption is fully pipelined in hardware

### SIMON Encrypt/Decrypt Roundtrip (from simulation)
```
Plaintext  :  15          (0x0000000F)
Ciphertext :  2398136562  (0x8ED6E772)
Decrypted  :  15          (0x0000000F)  ✅
```

---

## Applications

- **Health Sensor Nodes** — Encrypts patient vitals (ECG, SpO2, temperature) at hardware level with no firmware overhead
- **Smart Metering** — Secures utility consumption data before RF transmission; meets tamper-detection requirements
- **IoT Edge Devices** — 0.139W total power suitable for battery or energy-harvested operation
- **Wearable Devices** — 25.7°C junction temperature safe for body-worn applications

---

## Simulation

Simulate using any Verilog simulator (ModelSim, Vivado Simulator, Icarus Verilog):

```bash
# Icarus Verilog
iverilog -o mips_sim mips_top.v testbench.v
vvp mips_sim

# ModelSim
vlog mips_top.v testbench.v
vsim mips_top_tb
```

### Key signals to monitor in waveform

| Signal | What to check |
|--------|---------------|
| `IF_pc` | Increments +4 each cycle, freezes on stall, jumps on flush |
| `stall` | Goes high on `lw` → `beq` sequence (load-use hazard) |
| `flush` | Goes high when branch taken or jump executes |
| `EX_encrypted_data` | Should show `2398136562` when `sw` executes |
| `MEM_decrypted_data` | Should match original value after `lw` |
| `$13` (reg[13]) | Increments by 1 each loop — confirms jump working |

---

## File Structure

```
├── mips_top.v              # Top-level processor module
├── README.md               # This file
└── testbench.v             # Simulation testbench (if applicable)
```

---

## License

This project is developed for academic purposes.
