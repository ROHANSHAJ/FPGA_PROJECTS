# 👾 FPGA Space Shooter — 640x480 VGA Arcade Game in Verilog

[![FPGA: Xilinx Artix-7](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7%20(XC7A35T)-red.svg?logo=xilinx&logoColor=white)](https://www.xilinx.com/)
[![Board: Digilent Basys 3](https://img.shields.io/badge/Target%20Board-Digilent%20Basys%203-blue.svg)](https://digilent.com/reference/programmable-logic/basys-3/start)
[![HDL: Verilog](https://img.shields.io/badge/HDL-Verilog%202001-brightgreen.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Toolchain: Vivado](https://img.shields.io/badge/Toolchain-Xilinx%20Vivado-orange.svg)](https://www.xilinx.com/products/design-tools/vivado.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A hardware-accelerated **2D Space Shooter arcade game** implemented in pure **Verilog HDL** for the **Digilent Basys 3 (Xilinx Artix-7 XC7A35T)** FPGA board. The game features full **640x480 @ 60Hz VGA video generation**, hardware collision detection, debounced push-button flight controls, multi-level difficulty scaling, animated starfield backgrounds, and live score tracking on an on-board **4-digit 7-segment display**.

---

## 🎮 Gameplay & Mechanics

| Feature | Hardware Implementation |
| :--- | :--- |
| **Display Resolution** | 640 × 480 @ 60 Hz with 12-bit RGB color depth (4096 colors) |
| **Spaceship Controller** | Left (`btnL`) and Right (`btnR`) horizontal translation with boundary clipping |
| **Weapon System** | High-velocity projectile cannon fired with Up (`btnU`) button |
| **Enemy AI & Waves** | Up to 4 simultaneous enemies with dynamic bounding-box trajectory and bounce |
| **Difficulty Scaling** | On-the-fly difficulty selection via 2 hardware switches (`sw[1:0]`) |
| **Score System** | Real-time score counter rendered dynamically onto multiplexed 4-digit 7-segment displays |
| **Game State Machine** | 4-state Mealy/Moore FSM: `START` $\rightarrow$ `PLAY` $\leftrightarrow$ `PAUSE` $\rightarrow$ `GAMEOVER` |
| **Debounce Engine** | 20-bit counter-based hardware debouncer for clean Pause/Resume transitions |

---

## 🏗️ Hardware Architecture & Block Diagram

```text
               +-------------------------------------------------------------+
               |                    Digilent Basys 3 (Artix-7)               |
               |                                                             |
100 MHz CLK -->| [Pixel Clock Gen] ---> 25 MHz Pixel Tick                    |
               |         |                                                   |
               |         v                                                   |
               |   [VGA Sync] --------> HSYNC / VSYNC (P19, R19)             |
               |         |                                                   |
               |         v                                                   |
Controls ----->| [Game FSM & Logic]                                          |
(btnL, btnR,   |   * Ship Renderer                                           |
 btnU, btnD,   |   * Multi-Enemy Trajectory Engine                           |
 btnC, SW15)   |   * Bullet Physics & AABB Collision Detect                  |
               |   * Animated Starfield Generator                            |
               |         |                                                   |
               |         +------------> 12-bit Color DAC (vgaRed, vgaGreen,  |
               |         |                                vgaBlue)           |
               |         v                                                   |
               | [BCD Score Engine] --> 7-Segment Multiplexer (seg[6:0], an) |
               +-------------------------------------------------------------+
```

---

## 🕹️ Controls & Board Pinout

All pin assignments are defined in [`cons.xdc`](cons.xdc) for the Digilent Basys 3:

### 1. Push Buttons & Switches
| Signal | Basys 3 Pin | Function |
| :--- | :--- | :--- |
| `clk` | `W5` | 100 MHz On-Board Master Oscillator |
| `btnD` | `U17` | **Start Game** (Down Button) |
| `btnC` | `U18` | **Pause / Resume** (Center Button, Hardware Debounced) |
| `btnL` | `W19` | **Move Left** |
| `btnR` | `T17` | **Move Right** |
| `btnU` | `T18` | **Fire Bullet** (Up Button) |
| `reset_sw`| `R2` | **Master Hardware Reset** (Switch 15, Far Left) |
| `sw[0]` | `V17` | Level Selector Bit 0 |
| `sw[1]` | `V16` | Level Selector Bit 1 |

### 2. Difficulty Level Configuration (`sw[1:0]`)
| Switch State `sw[1:0]` | Difficulty Level | Max Enemies | Enemy Speed | Enemy Color |
| :---: | :---: | :---: | :---: | :---: |
| `00` | **Level 1 (Novice)** | 1 | 2 px/frame | Red (`#F00`) |
| `01` | **Level 2 (Normal)** | 2 | 3 px/frame | Magenta (`#F0F`) |
| `10` | **Level 3 (Hard)** | 3 | 4 px/frame | Cyan (`#0FF`) |
| `11` | **Level 4 (Insane)** | 4 | 5 px/frame | White (`#FFF`) |

### 3. VGA Video Output (12-bit DAC)
| Signal | Basys 3 Pins | Description |
| :--- | :--- | :--- |
| `vgaRed[3:0]` | `N19, J19, H19, G19` | 4-bit Red Color Channel |
| `vgaGreen[3:0]`| `D17, G17, H17, J17` | 4-bit Green Color Channel |
| `vgaBlue[3:0]` | `J18, K18, L18, N18` | 4-bit Blue Color Channel |
| `hsync` | `P19` | Horizontal Sync (31.468 kHz) |
| `vsync` | `R19` | Vertical Sync (59.94 Hz) |

### 4. 7-Segment Score Display
- **Anodes (`an[3:0]`):** `W4, V4, U4, U2`
- **Cathodes (`seg[6:0]`):** `W7, W6, U8, V8, U5, V5, U7`

---

## ⚡ Video Timing Specification (640 × 480 @ 60 Hz)

The timing generator in [`vga_sync.v`](vga_sync.v) divides the 100 MHz clock by 4 to generate a **25.175 MHz pixel clock**:

| Parameter | Horizontal (Pixels) | Vertical (Lines) |
| :--- | :--- | :--- |
| **Visible Area** | 640 | 480 |
| **Front Porch** | 16 | 10 |
| **Sync Pulse** | 96 | 2 |
| **Back Porch** | 48 | 33 |
| **Total** | 800 | 525 |
| **Frequency** | 31.468 kHz | 59.94 Hz |

---

## 🛠️ Build & Flash Instructions (Xilinx Vivado)

1. **Launch Vivado** (2018.1 or newer) and create a new RTL Project.
2. Select target part: **xc7a35tcpg236-1** (Digilent Basys 3).
3. **Add Design Sources:**
   - Add [`vga_sync.v`](vga_sync.v).
   - Set `space_shooter` as the **Top Module**.
4. **Add Constraints:**
   - Add [`cons.xdc`](cons.xdc).
5. **Run Synthesis & Implementation:**
   - Click **Run Synthesis** $\rightarrow$ **Run Implementation**.
   - Click **Generate Bitstream** (`space_shooter.bit`).
6. **Program the FPGA:**
   - Connect the Basys 3 board via micro-USB.
   - Open **Hardware Manager** $\rightarrow$ **Auto Connect**.
   - Select `xc7a35t_0` and program with `space_shooter.bit`.
7. **Connect VGA Cable:**
   - Plug a standard VGA cable from the Basys 3 board into any monitor/TV supporting 640x480 resolution.
   - Flip Switch 15 down, press `btnD` to launch, and defend your quadrant!

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
