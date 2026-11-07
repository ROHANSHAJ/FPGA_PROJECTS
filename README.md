# 👾 FPGA Space Shooter — 640×480 VGA Arcade Game in Verilog

[![FPGA: Xilinx Artix-7](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7%20(XC7A35T)-red.svg?logo=xilinx&logoColor=white)](https://www.xilinx.com/)
[![Board: Digilent Basys 3](https://img.shields.io/badge/Target%20Board-Digilent%20Basys%203-blue.svg)](https://digilent.com/reference/programmable-logic/basys-3/start)
[![HDL: Verilog](https://img.shields.io/badge/HDL-Verilog%202001-brightgreen.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Toolchain: Vivado](https://img.shields.io/badge/Toolchain-Xilinx%20Vivado-orange.svg)](https://www.xilinx.com/products/design-tools/vivado.html)
[![Resolution: 640x480@60Hz](https://img.shields.io/badge/VGA-640%C3%97480%20%40%2060Hz-purple.svg)](https://en.wikipedia.org/wiki/Video_Graphics_Array)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A high-performance, hardware-accelerated **2D Space Shooter arcade game** written in **Verilog HDL** for the **Digilent Basys 3 (Xilinx Artix-7 XC7A35T)** FPGA board. 

Unlike software games emulated on a microprocessor, this entire gaming pipeline—including pixel timing, sprite generation, projectile physics, multi-entity collision detection, and score tracking—executes in parallel logic gates at **60 frames per second** with **zero frame drops** and sub-microsecond latency.

---

## 📸 System Architecture

```text
                               +--------------------------------------------+
                               |     Digilent Basys 3 FPGA (XC7A35T)        |
                               +--------------------------------------------+
                                                      |
    [100 MHz Oscillator] ----> | 25 MHz Pixel Clock Divider                 |
                               |                   |                        |
                               |                   v                        |
                               | VGA Sync Engine (vga_sync)                 |
                               | ├── H-Sync & V-Sync Generator              | ---> [VGA Display]
                               | └── Pixel Coordinate Raster (X:0-639, Y:0-479)   (640x480 @ 60Hz)
                               |                   |                        |
    [Push Buttons] ----------> | Space Shooter Game Logic (space_shooter)  |
    (Up, Down, Left, Right)    | ├── Player Spaceship Kinematics            |
                               | ├── Laser Projectile Physics               |
    [Fire Button] -----------> | ├── Multi-Alien Swarm Patrol               |
                               | ├── Hardware Collision Detection Unit      |
                               | └── 12-Bit RGB Color DAC Pipeline          | ---> [12-Bit VGA Port]
                               |                   |                               (4R, 4G, 4B)
                               |                   v                        |
                               | 7-Segment Multiplexer (seven_seg_ctrl)    | ---> [4-Digit 7-Seg]
                               | └── BCD Score Counter & Refresh Engine     |      (Score Display)
                               +--------------------------------------------+
```

---

## 🎮 Gameplay & Mechanics

| Feature | Hardware Implementation |
| :--- | :--- |
| **Player Ship** | 16×16 pixel sprite, navigable in 2D space using directional pushbuttons (`btnU`, `btnD`, `btnL`, `btnR`). |
| **Laser Cannons** | High-velocity dual-beam laser projectiles spawned on trigger press (`btnC`). Automatically recycles off-screen. |
| **Alien Adversaries** | Autonomous alien squadron marching with oscillating patrol vectors and accelerating descent speeds. |
| **Collision Engine** | Purely combinational bounding-box intersection logic detecting laser-alien hits and alien-ship crashes. |
| **Scoreboard** | Live score register multiplexed across the 4-digit common-anode 7-segment display with BCD conversion. |
| **Visual Palette** | 12-bit color output (4,096 distinct hues) driving VGA resistor ladder DACs directly from FPGA I/O pins. |

---

## ⏱️ VGA Video Timing Specifications (640×480 @ 60 Hz)

The video synchronization generator (`vga_sync.v`) produces strict VESA-compliant timing derived from the onboard 100 MHz oscillator through a 2-bit counter ($100\text{ MHz} / 4 = 25\text{ MHz}$ pixel clock).

$$\text{Pixel Clock} = \frac{100\text{ MHz}}{4} = 25\text{ MHz}$$

```
Horizontal Scan (lines):
|<- Active: 640px ->|<- Front Porch: 16px ->|<- Sync Pulse: 96px ->|<- Back Porch: 48px ->| = 800 Clocks

Vertical Refresh (frames):
|<- Active: 480ln ->|<- Front Porch: 10ln ->|<- Sync Pulse: 2ln ->|<- Back Porch: 33ln ->| = 525 Lines
```

---

## 🔌 Basys 3 Master Pinout (`cons.xdc`)

All physical pin mappings are configured for the Digilent Basys 3 Xilinx Artix-7 FPGA:

### 1. Clock & System Controls
| Signal Name | FPGA Pin | I/O Standard | Description |
| :--- | :---: | :---: | :--- |
| `clk` | `W5` | LVCMOS33 | 100 MHz Onboard System Oscillator |
| `reset` | `V17` | LVCMOS33 | Slide Switch `SW0` (Active High Reset) |

### 2. Player Pushbutton Controls
| Signal Name | FPGA Pin | I/O Standard | Action |
| :--- | :---: | :---: | :--- |
| `btnC` | `U18` | LVCMOS33 | Fire Laser Cannon |
| `btnU` | `T18` | LVCMOS33 | Move Ship Up |
| `btnD` | `U17` | LVCMOS33 | Move Ship Down |
| `btnL` | `W19` | LVCMOS33 | Move Ship Left |
| `btnR` | `T17` | LVCMOS33 | Move Ship Right |

### 3. VGA 12-Bit Color & Synchronization
| Signal | Pins (Bit 3 .. Bit 0) | I/O Standard | Description |
| :--- | :--- | :---: | :--- |
| `vgaRed[3:0]` | `N19`, `J19`, `H19`, `G19` | LVCMOS33 | 4-bit Red Analog Weighting |
| `vgaGreen[3:0]` | `D17`, `G17`, `H17`, `J17` | LVCMOS33 | 4-bit Green Analog Weighting |
| `vgaBlue[3:0]` | `J18`, `K18`, `L18`, `N18` | LVCMOS33 | 4-bit Blue Analog Weighting |
| `hsync` | `P19` | LVCMOS33 | Horizontal Synchronization Pulse |
| `vsync` | `R19` | LVCMOS33 | Vertical Synchronization Pulse |

### 4. 4-Digit 7-Segment Display (Scoreboard)
| Signal | Pins | Description |
| :--- | :--- | :--- |
| `seg[6:0]` | `W7, W6, U8, V8, U5, V5, U7` | Segment Cathodes (CA .. CG) |
| `an[3:0]` | `W4, V4, U4, U2` | Digit Anodes (AN3 .. AN0) |

---

## 📁 Repository Structure

```text
FPGA_PROJECTS/
├── vga_sync.v       # Complete top-level Verilog file:
│                    #   ├── module vga_sync (VESA 640x480 timing generator)
│                    #   ├── module seven_seg_ctrl (4-digit multiplexed score engine)
│                    #   └── module space_shooter (Kinematics, sprites & collision FSM)
├── cons.xdc         # Xilinx Design Constraints file for Digilent Basys 3 board
└── README.md        # Comprehensive technical documentation & pinout guide
```

---

## 🛠️ Build & Programming Guide (Vivado)

1. **Launch Vivado** (2020.1 or newer recommended).
2. Click **Create Project** $\rightarrow$ **RTL Project**.
3. Select Part: **Artix-7** $\rightarrow$ **xc7a35tcpg236-1** (or Boards $\rightarrow$ **Basys 3**).
4. Add Design Sources:
   - Select `vga_sync.v`.
5. Add Constraints:
   - Select `cons.xdc`.
6. Click **Run Synthesis** $\rightarrow$ **Run Implementation**.
7. Click **Generate Bitstream**.
8. Connect your Basys 3 board via micro-USB and open **Hardware Manager**.
9. Click **Auto Connect**, select `xc7a35t`, and click **Program Device** with the `.bit` file.
10. Connect a standard 15-pin VGA cable to your monitor and enjoy the arcade game!

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
