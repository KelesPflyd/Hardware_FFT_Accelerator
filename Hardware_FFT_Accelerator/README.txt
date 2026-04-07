# Real-Time FFT Spectrum Analyzer (Hardware Accelerator IP)

A high-performance, real-time Fast Fourier Transform (FFT) hardware accelerator designed in Verilog. This IP core is optimized for FPGA implementation (target: Xilinx / Gowin Tang Nano 9K) to perform sub-millisecond RF spectrum analysis, making it ideal for autonomous systems, combat UAVs, and anti-jamming communication modules where software-based DSP processing introduces unacceptable latency.

## 🚀 Key Features & Capabilities

* **Algorithm:** 256-point Radix-2 Decimation-in-Time (DIT) FFT.
* **Datapath:** Custom-designed DSP Butterfly Unit utilizing `Q1.15` Fixed-Point arithmetic to prevent overflow and maintain high precision without the cost of floating-point logic.
* **Memory Architecture:** True Dual-Port RAM (BRAM inferred) allowing simultaneous read/write operations in a single clock cycle, coupled with automated **Bit-Reversal** addressing in hardware (0 logic gate cost).
* **Control Unit:** A highly optimized, sequential Finite State Machine (FSM) ensuring safe read/wait/calc/write cycles without pipeline deadlock.
* **Interface:** Integrated 57600 baud UART RX module with 16x oversampling and a dual-pointer Synchronous FIFO buffer for asynchronous data capture.
* **Performance:** Executes $O(N \log N)$ complexity math entirely in hardware. Once the 256th byte is received, the 8-stage analysis is completed in microseconds, identifying the frequency bins (including DC offset and Nyquist frequencies) deterministically.

## 🛠️ Architecture Overview

The system operates independently from any soft-core processor. Data flows through the following pipeline:
1. **UART RX & FIFO:** Captures raw 8-bit signal data from external sensors (e.g., RF telemetry modules like RFD900x) and buffers it until a 256-sample frame is ready.
2. **Top FSM (Controller):** Pulls data from the FIFO, converts it to 32-bit complex numbers (`Q1.15` format), and writes it to the Dual-Port RAM using bit-reversed indexing.
3. **Twiddle ROM:** Pre-calculated Sine/Cosine coefficients generated via MATLAB, stored in FPGA memory arrays for instant access.
4. **Butterfly Unit:** The arithmetic heart of the system. Reads data A and B from RAM, applies the twiddle factor $W$, and writes the cross-calculated $X$ and $Y$ back to the RAM.

## 📂 Repository Structure

* `/src`: Contains all synthesisable Verilog RTL source files (`fft_core_top.v`, `butterfly_unit.v`, etc.).
* `/sim`: Contains the behavioral testbench (`fft_core_tb.v`) which simulates a continuous square wave transmission via UART to validate the Nyquist frequency peak in the RAM bins.
* `/matlab`: Contains the `.mem` file for the ROM and scripts used for generating the fixed-point twiddle factors.

## 📊 Simulation Results

The system was extensively simulated using Xilinx Vivado. When fed a constant high-frequency alternating signal (`100, 0, 100, 0...`) via the simulated UART testbench, the hardware successfully isolated the fundamental frequency, resulting in a massive energy peak precisely at `ram[128]` (Nyquist bin) and `ram[0]` (DC offset), validating the core mathematical logic and FSM timing.

## 🎯 Target Applications
* Hardware-Accelerated Autonomous Systems
* UAV/Drone RF Telemetry monitoring and dynamic frequency hopping
* Real-time Jammer Detection and Notch Filtering
* Embedded Radar Signal Processing

## ⚙️ Development Tools
* **HDL:** Verilog-2001
* **Simulation:** Xilinx Vivado Simulator (XSim)
* **Synthesis Target:** Gowin GW1NR-9 (Tang Nano 9K) / Xilinx Series