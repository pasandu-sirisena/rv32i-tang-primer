# Tang Primer 20K RV32IM System-on-Chip

A pipelined 32-bit RISC-V (RV32IM) processor and System-on-Chip (SoC) implemented in Verilog HDL and verified on the Sipeed Tang Primer 20K FPGA dock (Gowin GW2A-LV18PG256C8/I7).

Built entirely using an open-source EDA toolchain (Yosys, NextPNR, Project Apicula, and openFPGALoader).

---

## 1. System Architecture

```
+------------------------------------------------------------------------------------+
|                               Tang Primer 20K SoC                                  |
|                                                                                    |
|   +-----------------------+     Wishbone Master    +---------------------------+  |
|   |                       |=======================>|      wb_interconnect      |  |
|   |      rv32im_core      |                        +-------------+-------------+  |
|   |  (5-Stage Pipeline)   |                                      |                 |
|   |                       |           +--------------------------+----------+      |
|   |  - IF / ID / EX /     |           |                          |          |      |
|   |    MEM / WB           |           v (0x0...)                 v (0x1...) v(0x2...)|
|   |  - RV32I Base ISA     |    +--------------+            +----------+ +--------+ |
|   |  - RV32M Mul/Div Unit |    |   wb_bram    |            | wb_uart  | |wb_gpio | |
|   |  - Forwarding & Hazard|    | 8 KB (2048x32|            | 115.2kBd | | 6-LED  | |
|   |    Management         |    | Dual-Port)   |            |  BL702   | | Dock   | |
|   +-----------+-----------+    +--------------+            +----+-----+ +---+----+ |
|               | (Port A)                                        |           |      |
|               +-------------------------------------------------+           |      |
|                                                                 v           v      |
|                                                               UART TX    LED[5:0]  |
+------------------------------------------------------------------------------------+
```

### Core Features
- **5-Stage Pipeline**: Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), and Writeback (WB).
- **RV32I Base ISA Support**: Complete support for integer arithmetic, logic operations, shifts, branches, jumps, loads, and stores.
- **RV32M Hardware Extension**:
  - Combinational 32-bit hardware multiplier (`MUL`, `MULH`, `MULHSU`, `MULHU`) utilizing FPGA DSP blocks.
  - Multi-cycle sequential restoring divider (`DIV`, `DIVU`, `REM`, `REMU`) with automatic pipeline stalling during computation.
- **Hazard Handling & Forwarding**:
  - Comprehensive operand forwarding paths (MEM to EX, WB to EX).
  - Load-use data hazard detection with single-cycle stall insertion.
  - Branch and jump resolution in the EX stage with pipeline flushing.
- **Clock & Reset**:
  - 27.0 MHz system clock from onboard crystal oscillator.
  - 8-bit power-on reset generator ensuring clean startup across clock domains.
- **Memory Subsystem**:
  - 8 KB dual-port block RAM (2048 x 32-bit words) mapped directly to 8 native Gowin `DPX9B` BSRAM slices.
  - Port A: Dedicated synchronous instruction fetch port.
  - Port B: Wishbone slave data access port (supporting 8-bit, 16-bit, and 32-bit load/store operations).

---

## 2. Memory & Peripheral Map

The system uses a Wishbone B4 interconnect decoded by address bits `[31:28]`:

| Address Range | Device | Description | Access |
| :--- | :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_1FFF` | BRAM | 8 KB instruction and data RAM | R/W |
| `0x1000_0000 - 0x1000_000F` | UART | Full-duplex UART controller (115,200 baud) | R/W |
| `0x2000_0000 - 0x2000_0003` | GPIO | 6-bit LED output controller | R/W |

### UART Register Offsets (`0x1000_0000`)
- `+0x00` (`TXDATA`): Write byte to initiate UART transmission.
- `+0x04` (`TXSTATUS`): Read bit `[0]` (1 = transmitter busy, 0 = ready).
- `+0x08` (`RXDATA`): Read received byte (clears receive ready flag).
- `+0x0C` (`RXSTATUS`): Read bit `[0]` (1 = byte available, 0 = empty).

### GPIO Register Offsets (`0x2000_0000`)
- `+0x00` (`DATA`): Read/Write bits `[5:0]` corresponding to the 6 onboard LEDs.

---

## 3. Physical Pinout Constraints

Pin assignments for the Sipeed Tang Primer 20K Dock board (`constraints/primer20k_dock.cst`):

| Signal | Pin | Standard | Description |
| :--- | :--- | :--- | :--- |
| `clk_27mhz` | `H11` | LVCMOS33 | 27.0 MHz oscillator |
| `led_n[0]` | `C13` | LVCMOS33 | Dock LED 0 (active-low) |
| `led_n[1]` | `A13` | LVCMOS33 | Dock LED 1 (active-low) |
| `led_n[2]` | `N16` | LVCMOS33 | Dock LED 2 (active-low) |
| `led_n[3]` | `N14` | LVCMOS33 | Dock LED 3 (active-low) |
| `led_n[4]` | `L14` | LVCMOS33 | Dock LED 4 (active-low) |
| `led_n[5]` | `L16` | LVCMOS33 | Dock LED 5 (active-low) |
| `uart_tx` | `M11` | LVCMOS33 | UART TX to BL702 USB bridge |
| `uart_rx` | `T13` | LVCMOS33 | UART RX from BL702 USB bridge |

---

## 4. Repository Structure

```
.
├── constraints/
│   └── primer20k_dock.cst     # Physical pin locations and IO definitions
├── rtl/
│   ├── alu.v                  # RV32I integer arithmetic logic unit
│   ├── divider.v              # Multi-cycle sequential restoring divider
│   ├── firmware.hex           # Assembled hex firmware loaded into BRAM
│   ├── forwarding_unit.v      # Operand forwarding multiplexer controller
│   ├── hazard_unit.v          # Stall and flush hazard detection unit
│   ├── multiply.v             # Combinational 32-bit hardware multiplier
│   ├── pll_50mhz.v            # Gowin rPLL clock multiplier module
│   ├── regfile.v              # 32x32-bit dual-read single-write register file
│   ├── rv32im_core.v          # 5-stage pipelined processor core
│   ├── top.v                  # Top-level SoC interconnect and peripheral wrapper
│   ├── wb_bram.v              # Dual-port 8 KB Wishbone BRAM memory
│   ├── wb_gpio.v              # 6-bit Wishbone GPIO peripheral
│   ├── wb_interconnect.v      # Wishbone B4 bus interconnect and decoder
│   └── wb_uart.v              # Wishbone UART peripheral (115200 baud)
├── sim/
│   ├── assemble.py            # 2-pass Python assembler with automatic label resolution
│   ├── gowin_rpll_sim.v       # Behavioral simulation model for Gowin rPLL
│   └── tb_top.v               # Self-checking testbench with UART monitor
├── build/
│   └── synth.ys               # Yosys synthesis script
└── README.md                  # Project documentation
```

---

## 5. Toolchain & Build Instructions

### Prerequisites
Install the open-source FPGA toolchain (Yosys, NextPNR, Project Apicula, openFPGALoader, and Python 3):
- **Yosys** (Synthesis)
- **nextpnr-himbaechel** (Place and Route for Gowin)
- **apycula / gowin_pack** (Bitstream packaging)
- **openFPGALoader** (JTAG programmer)

### Assembling Firmware
To assemble the sample firmware into `rtl/firmware.hex`:
```bash
python sim/assemble.py
```

### Full Synthesis & FPGA Flashing
Run the build commands to synthesize, place, route, and flash the bitstream into FPGA SRAM:

```bash
# 1. Synthesize RTL to JSON netlist
yosys -q -l build/yosys.log -s build/synth.ys

# 2. Place and Route for GW2A-18
nextpnr-himbaechel --json build/top.json \
                   --write build/top_pnr.json \
                   --device "GW2A-LV18PG256C8/I7" \
                   --vopt "family=GW2A-18" \
                   --vopt "cst=constraints/primer20k_dock.cst" \
                   --freq 27 -q

# 3. Pack bitstream
gowin_pack -d GW2A-18 -o build/top.fs build/top_pnr.json

# 4. Program FPGA SRAM via JTAG
openFPGALoader -b tangprimer20k -m build/top.fs
```

---

## 6. Simulation

Run testbench simulation using Icarus Verilog:

```bash
iverilog -g2012 -o build/sim.out \
    sim/tb_top.v \
    sim/gowin_rpll_sim.v \
    rtl/top.v \
    rtl/rv32im_core.v \
    rtl/alu.v \
    rtl/multiply.v \
    rtl/divider.v \
    rtl/regfile.v \
    rtl/hazard_unit.v \
    rtl/forwarding_unit.v \
    rtl/wb_interconnect.v \
    rtl/wb_bram.v \
    rtl/wb_uart.v \
    rtl/wb_gpio.v

vvp build/sim.out
```

Waveforms are generated at `build/waves.vcd` and can be inspected using GTKWave.
