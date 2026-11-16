<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

MORPH is an open-source, reprogrammable protocol emulator ASIC built around a custom 8-bit processor. Its goal is to support hardware communication protocols such as UART, SPI, and I²C through software-controlled GPIO rather than dedicated protocol-specific hardware.

The current implementation contains an 8-bit CPU, a 256 × 16-bit instruction memory, a UART receiver, and a program loader. The CPU supports arithmetic and logical operations, immediate loading, and conditional and unconditional branching.

Firmware is uploaded through a dedicated UART programming interface operating at 115200 baud with an intended 50 MHz system clock. The UART receiver converts incoming serial data into 8-bit bytes. The program loader assembles groups of three bytes into an 8-bit memory address and a 16-bit instruction, which is written into instruction memory.

The programming mode input controls whether the CPU is paused for programming or allowed to execute instructions. The current design exposes the 8-bit program counter through its dedicated output pins for debugging.

Programmable GPIO, additional processor instructions, and protocol-emulation firmware are planned for subsequent development.



## How to test

The current design uses the following dedicated input signals:

ui_in[0]: UART programming input (RX).

ui_in[1]: Programming mode (1 = programming, 0 = execution).

clk: System clock, designed for 50 MHz.

rst_n: Active-low reset.

The eight dedicated outputs, uo_out[7:0], expose the CPU's program counter.

To upload an instruction, assert programming mode and transmit three bytes over UART in the following order:

Instruction memory address (8 bits).

Instruction high byte (bits 15–8).

Instruction low byte (bits 7–0).

Repeat this sequence for each instruction. After uploading the program, deassert programming mode to allow the CPU to execute instructions.

The individual CPU, UART receiver, and program loader have been tested in simulation. End-to-end serial programming and execution verification is still in progress.



## External hardware

The current design can be programmed using an external 3.3 V-compatible USB-to-UART adapter connected to the UART RX input, with a shared ground and appropriate logic-level compatibility.

No external peripherals are required for the initial simulation tests. Future versions will support external devices through programmable GPIO pins.
