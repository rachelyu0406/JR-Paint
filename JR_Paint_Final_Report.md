# JR Paint Final Report

**Course:** ECE 350  
**Project Team:** Rachel Yu and Jill Wang  

## 1. Project Overview and Specifications

JR Paint is an FPGA-based interactive paint application built for the Nexys A7 board. The project combines a custom five-stage pipelined processor, assembly-level application logic, VGA video output, PS/2 mouse input, color-dependent audio output, and board feedback peripherals into one integrated system. The system allows a user to draw on a VGA monitor using a real mouse, change colors and pen sizes with board switches, fill connected regions, undo strokes, clear the canvas, and hear a short sound effect associated with the active drawing color.

The central design decision was to split the system into two layers:

1. A **hardware layer** in RTL/behavioral Verilog and VHDL that handles timing-critical and protocol-specific tasks such as VGA scan timing, PS/2 signaling, memory interfaces, cursor sprite rendering, and audio playback.
2. A **software layer** in assembly that runs on the custom processor and acts as the application brain. The processor decides how the cursor moves, when drawing occurs, how fill bucket and undo work, which color is active, which pen size is active, and when to clear the screen.

This split was intentional. A pure hardware implementation would have required much more control logic for fill, undo, and user interaction, while a pure software framebuffer implementation at full 640x480 resolution would have been too memory-heavy and inefficient for the processor. Instead, the design stores a compact logical canvas and lets hardware expand and display it efficiently.

### Functional Specifications

- VGA output at 640x480 visible resolution.
- Logical drawing canvas stored as an 80x60 grid, with each canvas cell displayed as an 8x8 VGA block.
- Ten selectable drawing colors: white, pink, red, orange, yellow, green, blue, purple, brown, and black.
- Five selectable pen sizes corresponding to 0.2, 0.4, 0.6, 0.8, and 1.0.
- PS/2 mouse input for cursor movement and button-based interaction.
- Left click draws, right click undoes, middle click clears, and switch 15 enables fill-bucket mode.
- Center board button (`BTNC`) also clears the canvas.
- RGB LED indicates the currently selected color.
- Seven-segment display indicates the currently selected pen size.
- Audio cue changes with the selected color and is played from pre-recorded `.wav` files converted into FPGA memory.

## 2. Overall Design

The final top-level design is implemented in `final_project_vga_files/FinalProjectJRPaint.v`. The system is organized around a custom processor connected to a memory-mapped I/O (MMIO) layer.

At a high level, the dataflow is:

```text
PS/2 Mouse
   |
   v
Ps2Interface (VHDL) -> MousePacketDecoder -> MMIO registers
                                              |
                                              v
                                   Custom Processor + Assembly
                                              |
                         ---------------------------------------------
                         |                     |                     |
                         v                     v                     v
                    Canvas writes         Cursor registers      LED/Pen/Audio state
                         |                     |                     |
                         v                     v                     v
                  CanvasMemory RAM      Cursor overlay logic   Audio controller
                         |
                         v
              Palette lookup + VGA timing generator
                         |
                         v
                     VGA monitor
```

This block diagram was constructed directly from the module boundaries and signal flow in `FinalProjectJRPaint.v`, rather than from a hand-drawn gate-level schematic. That choice reflects the actual design methodology of the project: this system is best understood as a composition of higher-level hardware modules and software state machines rather than as a collection of isolated combinational circuits.

### 2.1 Clocking and Reset

The design starts from the Nexys A7 100 MHz board clock. A clock wizard generates the 25 MHz pixel clock used for VGA timing and for the processor/MMIO/video path. The top-level reset is derived from the PLL lock signal, ensuring that the rest of the system only starts after the clocking is stable.

This choice simplified synchronization between the CPU, cursor registers, canvas RAM, and VGA output. The audio path remains driven from the 100 MHz clock so the PWM serializer can run at a higher rate.

### 2.2 Display Pipeline

The VGA display logic uses a timing generator to produce the current screen coordinates (`x`, `y`) and active-video window. The visible screen is 640x480, but the actual drawing surface is not stored at full pixel resolution. Instead, the current screen coordinates are divided by 8 to index into an 80x60 canvas memory. This means each logical cell occupies an 8x8 pixel square on the monitor.

The canvas memory stores only a 4-bit color index per cell. That color index is passed through a palette loaded from `colors.mem`, which produces the final 12-bit RGB color. This was a deliberate memory optimization: storing palette indices is much cheaper than storing full RGB for every logical cell.

The cursor is handled separately. It is stored as a one-bit sprite in `cursor.mem`, scaled dynamically in hardware to match the selected pen size, and then overlaid on top of the canvas display. Because the cursor is an overlay rather than part of the canvas RAM, it can move freely without permanently altering the drawing unless the processor explicitly chooses to paint.

### 2.3 Processor/MMIO Layer

The processor executes the application program stored in `finalprojectJRPaint_assembly.mem`, which is assembled from `finalprojectJRPaint_assembly.s` using Rachel’s assembler in `rachel_processor/assembler-python-version/assemble.py`.

The hardware exposes board state and control points through MMIO addresses. The important ones are:

| Address | Function |
|---|---|
| 4096 | Mouse `dx` |
| 4097 | Mouse `dy` |
| 4098 | Mouse buttons |
| 4099 | Mouse packet ready / acknowledge |
| 4100 | Frame toggle |
| 4101 | Cursor X register |
| 4102 | Cursor Y register |
| 4103 | `BTNC` clear button |
| 4104 | Switch input |
| 4105 | Current LED/audio color |
| 4106 | Pen size |
| 8192..12991 | Canvas drawing window |

This memory map is important because it is the interface boundary between software and hardware. The processor does not directly know about VGA timing or PS/2 signal edges; it only knows about MMIO words and memory writes.

### 2.4 Memory and Data Representation

The design uses several different storage formats because different subsystems have different needs:

- **Instruction memory** holds the assembled JR Paint application program.
- **Processor RAM** holds software-managed state such as switch timestamps, the packed shadow canvas, the undo stack, and the DFS stack used by fill bucket.
- **Canvas memory** holds the visible drawing surface as one 4-bit palette index per logical pixel.
- **Palette ROM** maps color indices to 12-bit RGB values.
- **Cursor ROM** stores a 1-bit sprite mask for the crosshair.
- **Audio sample ROM** stores 8-bit sample values loaded from `color_audio.mem`.

This separation was important. Canvas memory is optimized for display. Processor RAM is optimized for software data structures. Audio ROM is optimized for sequential playback. Trying to force all of these into one uniform memory structure would have made both the hardware and the software more complex.

## 3. Inputs and Outputs

### Inputs

| Input | Role in Final Design |
|---|---|
| `ps2_clk`, `ps2_data` | PS/2 mouse communication |
| `SW[9:0]` | Color selection switches |
| `SW[14:10]` | Pen size selection switches |
| `SW[15]` | Fill bucket mode enable |
| Left mouse button | Draw or fill depending on mode |
| Right mouse button | Undo last stroke/fill |
| Middle mouse button | Clear canvas |
| `BTNC` | Clear canvas |
| `clk` | 100 MHz board clock |

The directional pushbuttons remain present in the top-level interface for compatibility with the board constraints, but the final JR Paint user interaction is mouse-driven.

### 3.1 User-Control Map

The interface is intentionally simple: the mouse handles pointing and click-based actions, while the board switches select persistent tool state.

| Control | Meaning |
|---|---|
| `SW0` | White draw color |
| `SW1` | Pink draw color |
| `SW2` | Red draw color |
| `SW3` | Orange draw color |
| `SW4` | Yellow draw color |
| `SW5` | Green draw color |
| `SW6` | Blue draw color |
| `SW7` | Purple draw color |
| `SW8` | Brown draw color |
| `SW9` | Black draw color |
| `SW10` | Pen size 0.2 |
| `SW11` | Pen size 0.4 |
| `SW12` | Pen size 0.6 |
| `SW13` | Pen size 0.8 |
| `SW14` | Pen size 1.0 |
| `SW15` | Fill-bucket mode enable |
| Left mouse | Draw or fill |
| Right mouse | Undo |
| Middle mouse | Clear canvas |
| `BTNC` | Clear canvas |

Two behavioral details matter here:

1. Color selection uses a “last switched on wins” policy rather than a fixed-priority policy.
2. Pen-size selection uses a fixed-priority policy in which larger sizes override smaller sizes when multiple size switches are high.

### Outputs

| Output | Role in Final Design |
|---|---|
| `VGA_R`, `VGA_G`, `VGA_B`, `hSync`, `vSync` | VGA display output |
| `LED17_R`, `LED17_G`, `LED17_B` | Active color feedback |
| `DISP_SEG_*`, `DISP_DP`, `DISP_EN` | Pen size display |
| `audioOut`, `audioEn`, `chSel` | Audio jack output |

## 4. Processor Use and Processor Modifications

The processor used in the final system is Rachel Yu’s five-stage pipelined processor in `rachel_processor/proc`. It includes:

- Fetch, Decode, Execute, Memory, and Writeback stages.
- Bypassing logic for data hazards.
- Load-use stalling.
- Branch/jump redirection.
- Multi-cycle multiply/divide support through a separate `multdiv` path.

### 4.1 Processor Modifications

A notable point in this project is that we did **not** need to redesign the processor datapath itself to build JR Paint. The core processor pipeline, hazard handling, and mult/div support already existed and were reused. Project-specific work was concentrated in:

- The top-level wrapper (`FinalProjectJRPaint.v`).
- The MMIO map for mouse/cursor/LED/audio/pen/canvas access.
- The instruction memory contents (`finalprojectJRPaint_assembly.mem`).
- The integration RAMs and ROMs used by the application.

Therefore, the most accurate wording for the report is:

> We did not modify the internal datapath of the selected processor core during final JR Paint integration; instead, we built a processor-centric SoC-style wrapper around it, added application-specific MMIO, and wrote a substantial assembly program to implement the paint application.

This is still a valid and important design decision. It demonstrates that the processor was sufficiently general-purpose to support a complex interactive application without requiring a custom one-off datapath redesign.

## 5. Assembly Program Overview

The assembly program is the behavioral core of the application. It is responsible for all user-facing logic and essentially acts like a small operating loop for the paint system.

### 5.1 Main Responsibilities of the Assembly Program

The assembly code:

- Initializes cursor position, pen size, selected color, and stack pointers.
- Waits for either a new frame or a new mouse packet.
- Reads switch states and decides the active color.
- Implements the “last switched on wins” color-selection rule.
- Reads pen-size switches and selects the active brush size.
- Reads mouse deltas and buttons from MMIO.
- Applies movement thresholding and updates the logical cursor position.
- Writes new cursor coordinates to MMIO so hardware can render the cursor overlay.
- Paints brush footprints into the canvas memory.
- Runs fill bucket with a stack-based DFS flood fill.
- Maintains undo history.
- Handles full-screen clear.

At startup, the program places the cursor at the center of the logical canvas (`x = 40`, `y = 30`), initializes the current cell index to 2440, clears color selection state, initializes pen size to 0.2, and positions the undo stack pointer in processor RAM. This means the system comes up in a consistent move-only state before any drawing color is selected.

### 5.2 Color Selection

Colors are not selected through simple fixed-priority switch logic. Instead, the assembly keeps per-color timestamps in low processor RAM and uses them to decide which active color switch was turned on most recently. This yields the intended “last switched on wins” behavior even when multiple color switches remain high simultaneously.

This was an example of behavior that was easier and cleaner to express in software than in hardwired combinational control.

More specifically, low RAM addresses are used as lightweight software state:

- Address `0`: previous sampled color-switch bitmap
- Address `1`: monotonically increasing software timestamp
- Addresses `2..11`: per-color “last rising-edge” timestamps

On each frame, the program compares the current switch bitmap against the previous bitmap, detects rising edges, updates the timestamp for any color whose switch has just turned on, and then scans the active colors to choose the one with the largest timestamp.

### 5.3 Cursor Motion

The processor reads `dx` and `dy` from MMIO and accumulates them into software remainders. Cursor movement only happens after the accumulated delta crosses a threshold. This acts as a sensitivity reduction and smooths movement so the cursor is controllable on the 80x60 grid.

The processor then:

- Updates logical cursor coordinates.
- Updates the linear cell index.
- Clamps movement to valid bounds.
- Writes the final cursor position back to MMIO registers 4101 and 4102.

### 5.4 Drawing

The brush is implemented entirely in assembly. The code computes a square footprint centered on the logical cursor cell, based on the selected pen size. It then iterates through the cells in that footprint, performs bounds checks, reads the prior color from the shadow canvas stored in processor RAM, logs undo information when the pixel changes, and writes the new color both to the shadow structure and the visible canvas MMIO region.

The canvas stored in visible draw memory is 4-bit indexed color. A separate packed shadow representation stored in processor RAM keeps four logical pixels per 32-bit word. That packed copy exists so the processor can do efficient read-modify-write operations and record prior values for undo without having to rely only on the visible canvas RAM.

### 5.5 Fill Bucket

The fill bucket is a stack-based DFS flood fill. When fill mode is enabled and the user clicks:

1. The assembly reads the target color at the clicked cell.
2. It rejects the fill if the target color already matches the replacement color.
3. It pushes the seed location onto a software stack in processor RAM.
4. It repeatedly pops a location, checks whether it still matches the target, recolors it, and pushes neighbors.

A special fast path detects the “entire screen / outside region” case and handles it directly. This path was important for correctness when filling the outside of complex drawings.

### 5.6 Undo

Undo is also software-driven. The processor maintains an undo stack in RAM. It pushes:

- A stroke delimiter (`-1`) when a new stroke starts.
- Encoded pixel history for normal brush writes.
- Special negative tags for fill operations and full-screen fills.

When the user right-clicks, the processor pops entries until it reaches the previous delimiter, restoring prior pixel values. Fill operations use special tags so they can be reversed correctly as region operations rather than as arbitrary single-pixel changes.

The undo stack grows upward from a fixed base in processor RAM, while the fill-bucket DFS stack grows downward from the top of RAM. This layout let us support both history and graph traversal without adding a second general-purpose memory.

## 6. PS/2 Mouse and Input Handling

The design uses two separate layers for mouse input:

1. `Ps2Interface.vhd` handles the low-level PS/2 wire protocol.
2. `MousePacketDecoder` in `FinalProjectJRPaint.v` interprets mouse packets.

`Ps2Interface` is a generic bidirectional PS/2 transport layer. It handles:

- Open-collector clock and data behavior.
- Debouncing and synchronization of the asynchronous PS/2 lines.
- 11-bit PS/2 framing (start, 8 data, parity, stop).
- Host-to-device transmit and device-to-host receive FSMs.

`MousePacketDecoder` then adds mouse-specific meaning. It waits for the standard PS/2 mouse startup sequence:

- `0xAA` self-test passed
- `0x00` mouse ID
- sends `0xF4` to enable streaming
- waits for `0xFA` acknowledge

After that, it groups incoming bytes into 3-byte mouse packets. Byte 0 contains button bits, sign bits, and overflow bits. Byte 1 is X movement. Byte 2 is Y movement. The decoder sign-extends the X and Y values into `dx` and `dy`, ignores overflowed motion, and raises `packetReady` when a complete movement packet has been processed.

This division of labor was an important design decision:

- The VHDL PS/2 block handles physical protocol timing.
- The Verilog decoder handles mouse semantics.
- The processor handles application behavior.

## 7. Audio System

The audio system is based on pre-recorded `.wav` clips, one per color. The final design uses:

- `build_color_audio_mem.py` to convert the `.wav` files in `sound_effects/`
- `color_audio.mem` to store concatenated sample data
- `color_audio_table.vh` to store clip start/length metadata
- `ColorAudioController` in `FinalProjectJRPaint.v`
- `PWMSerializer` from the Lab 9 kit for audio output

The active drawing color is mirrored into a hardware register (`ledColor`). When that register changes, the audio controller starts playback of the corresponding clip segment from `color_audio.mem`. Samples are read from block ROM and converted into a PWM waveform for the audio jack.

This implementation is intentionally similar to the Lab 9 structure: a memory-based sample source feeds a PWM-based audio output stage. The main project-specific extension was replacing synthetic tone selection with color-indexed playback of recorded sound effects.

In the final build, the audio sample ROM depth is 109,397 samples with a 17-bit sample address. The generated `color_audio_table.vh` file stores the exact start address and length of each clip so the playback logic does not need hardcoded magic numbers.

## 8. Circuit Diagrams and Rationale

The following diagrams are architecture diagrams rather than transistor/gate schematics, because that level of abstraction is the one that best matches how the project was actually designed and debugged.

### 8.1 System Block Diagram

```text
                 +----------------------+
Mouse ---------->|  Ps2Interface (VHDL) |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |  MousePacketDecoder  |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |   MMIO Registers     |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |  Processor + Assembly|
                 +-----+----------+-----+
                       |          |
                       |          +-------------------+
                       v                              v
              +----------------+           +----------------------+
              |  CanvasMemory  |           | Cursor / LED / Audio |
              +--------+-------+           +----------------------+
                       |
                       v
              +----------------------+
              | VGA Timing + Palette |
              +----------+-----------+
                         |
                         v
                      VGA Out
```

### 8.2 Memory Organization

```text
Processor RAM (4096 words total)

0 .. 11       : switch state and color-selection timestamps
64 .. 1263    : packed shadow canvas (4 logical pixels per word)
1264 .. ...   : undo stack (grows upward)
... .. 4095   : DFS fill stack (grows downward from top)

Separate CanvasMemory:
8192 .. 12991 : visible 80x60 drawing canvas (one 4-bit color index per cell)
```

This organization was chosen because it allowed us to use the provided processor RAM as general-purpose application storage while keeping the visible drawing surface in a dedicated hardware memory that the VGA path could read efficiently.

## 9. Challenges and How We Overcame Them

### 9.1 Fill Bucket on Large or Outside Regions

The first fill bucket implementation only worked on simpler regions and broke on larger areas or the “outside” of manually drawn shapes. The root cause was that the earlier logic did not robustly manage traversal state across large connected regions and did not properly handle the full-screen background case.

We fixed this by implementing a software stack-based DFS flood fill in assembly, storing traversal state explicitly in processor RAM. We also added a dedicated fast path for the full-screen/outside fill case so that the background could be recolored correctly even when bounded by user-drawn structures.

### 9.2 Undo After Fill

Undo originally worked for ordinary strokes but corrupted the image after fill bucket operations. The problem was that fills are fundamentally region operations, so trying to treat them as a sequence of ordinary pixel updates was not robust enough.

We solved this by extending the undo format with special negative tags for fills and full-screen fills, allowing the undo path to distinguish stroke history from fill history and reverse the correct operation type.

### 9.3 Audio Playback

Audio did not work correctly at first. There were two problems:

- The audio ROM loading path was fragile.
- Playback control only handled an initial case and not reliable color-triggered clip selection.

We corrected the sample-ROM loading path, generated explicit clip metadata in `color_audio_table.vh`, and simplified playback so the audio controller restarts the correct clip whenever the selected color changes.

### 9.4 Mouse Parsing and Cursor Stability

The first mouse-driven versions had erratic behavior, including jumps and poor responsiveness. These issues came from PS/2 packet handling, sensitivity, and how deltas were consumed.

We stabilized the path by:

- Keeping the low-level PS/2 protocol in dedicated hardware.
- Grouping bytes into complete packets before exposing motion.
- Accumulating `dx` and `dy`.
- Applying movement thresholding in assembly before advancing one logical canvas cell.

### 9.5 Cursor and Drawing Alignment

The cursor and brush footprint needed to remain visually aligned as pen size changed. The hardware cursor overlay scales the cursor sprite, while the assembly chooses the actual brush footprint. We refined both sides together so the cursor stayed centered on the actual painted region.

## 10. Test Plan and Results

Our test plan combined prior processor verification, integration checks, synthesis/implementation reports, and on-board functional testing.

### 10.1 Processor Validation

The Rachel processor repository contains a large suite of processor-focused test artifacts (for branches, loads, bypassing, mult/div, exceptions, jumps, and sorting workloads). These were part of the processor development process and provided confidence that the core pipeline, hazard logic, and mult/div path were stable before project integration.

For the final project, we did not modify the internal processor pipeline, so our project-specific testing focused on integration and application behavior rather than re-validating the entire datapath from scratch.

### 10.2 Module and Integration Testing

We tested the final system in stages:

1. **Display-only bring-up**  
   Verified VGA timing, background color, and canvas readout.

2. **Processor-to-canvas writes**  
   Confirmed that the processor could write to the canvas MMIO region and the changes appeared on-screen.

3. **Cursor overlay**  
   Verified that hardware overlay cursor rendering tracked software cursor coordinates.

4. **PS/2 mouse path**  
   Verified mouse initialization, packet decoding, signed movement, and button decoding.

5. **Color and pen size selection**  
   Verified switch inputs, LED feedback, and seven-segment display behavior.

6. **Brush drawing**  
   Verified stroke initiation, brush footprint, and on-screen persistence.

7. **Undo**  
   Verified ordinary stroke reversal and later verified fill reversal.

8. **Fill bucket**  
   Verified fill inside bounded regions, fill outside drawn shapes, and full-screen fill.

9. **Audio**  
   Verified that each color change triggered the expected sound clip.

10. **System regression on hardware**  
    Re-tested clear, undo, draw, fill, pen size, cursor scaling, and audio after each major integration change.

### 10.3 Hardware Acceptance Matrix

To keep testing organized, we treated the board demo as a set of observable acceptance tests:

| Test | Expected Result | Result |
|---|---|---|
| Cursor moves with mouse | Cursor tracks PS/2 movement without drawing when no color is selected | Passed |
| Draw with left mouse | Canvas updates at cursor location and remains on screen | Passed |
| Right-click undo | Most recent stroke or fill is removed | Passed |
| Middle-click clear | Entire canvas resets to background color | Passed |
| `BTNC` clear | Entire canvas resets to background color | Passed |
| Color switch selection | Active draw color changes and RGB LED reflects selected color | Passed |
| Last-switched-on color | Most recently enabled active color becomes current color | Passed |
| Pen size switch selection | Brush footprint and cursor size follow selected size | Passed |
| Seven-segment output | Display shows the active pen size value | Passed |
| Fill bucket inside region | Connected region is recolored correctly | Passed |
| Fill bucket outside region | Exterior background region can be recolored correctly | Passed |
| Audio cue on color change | Color-specific clip plays when selected color changes | Passed |

### 10.4 Quantitative Results

From the final synthesis utilization report for `FinalProjectJRPaint`:

- 4019 LUTs used (6.34%)
- 1995 registers used (1.57%)
- 11.5 block RAM tiles used (8.52%)
- 1 DSP used (0.42%)

These results show that the design comfortably fits on the Artix-7 100T device and still leaves substantial headroom for future features.

From the routed timing summary:

- The 25 MHz VGA domain met timing with positive slack (`WNS = 4.557 ns`).
- The report still contained a negative slack path on the 100 MHz domain (`WNS = -2.094 ns`) together with methodology warnings related to clock-tree handling and constraints.

In practice, the completed system functioned correctly on hardware for the intended course demonstration. The main takeaway is that the video/control domain was comfortably within timing, while the remaining high-frequency path was the main area where additional timing cleanup would be valuable in future work.

## 11. Code Overview

The final project codebase is divided into a few major categories:

### 11.1 Top-Level and Peripherals

- `FinalProjectJRPaint.v`  
  Final top-level integration of CPU, MMIO, VGA, cursor, LED, seven-segment, PS/2 decode, and audio.

- `VGATimingGenerator.v`  
  Produces VGA timing and coordinates.

- `Ps2Interface.vhd`  
  Low-level bidirectional PS/2 protocol engine.

### 11.2 Application Software

- `finalprojectJRPaint_assembly.s`  
  Main paint application logic in assembly.

- `finalprojectJRPaint_assembly.mem`  
  Assembled instruction image loaded by the processor.

- `rachel_processor/assembler-python-version/assemble.py`  
  Custom assembler used to regenerate the instruction memory.

### 11.3 Data Assets

- `colors.mem`  
  RGB palette.

- `cursor.mem`  
  Cursor sprite.

- `color_audio.mem`  
  Concatenated audio samples.

- `color_audio_table.vh`  
  Start/length table for the audio clips.

- `sound_effects/*.wav`  
  Source recordings for audio cues.

### 11.4 Processor Core

- `rachel_processor/proc/processor.v`
- `rachel_processor/proc/alu.v`
- `rachel_processor/proc/multdiv.v`
- `rachel_processor/proc/regfile.v`
- `rachel_processor/proc/RAM.v`
- `rachel_processor/proc/ROM.v`

Together these implement the five-stage pipelined CPU used as the compute core of the project.

## 12. Improvements and Future Work

If we had more time, the next improvements we would prioritize are:

1. **Save/export functionality**  
   Export the canvas to a computer over UART or save it to external storage.

2. **Import/load functionality**  
   Allow previously saved drawings to be reloaded.

3. **More tools**  
   Eraser, line, rectangle, circle, and spray brush tools.

4. **Higher-resolution canvas**  
   Increase logical resolution or add zoom/pan support.

5. **Deeper and more memory-efficient undo**  
   The current undo stack is limited by processor RAM. A compressed or external-history format would help.

6. **Cleaner timing closure**  
   Improve the remaining timing and clock-constraint issues on the 100 MHz path.

7. **Better audio control**  
   Volume control, clip mixing, or higher-fidelity playback.

8. **More polished on-screen UI**  
   Display active color, fill mode, and tool state directly on the VGA output.

## 13. Photos of the Project

Insert final hardware photos in the PDF version of the report. Suggested figures:

- **Figure 1:** FPGA board, mouse, speaker, and VGA monitor connected.
- **Figure 2:** Live drawing session showing cursor, brush, and canvas.
- **Figure 3:** Fill bucket or undo demonstration.
- **Figure 4:** Seven-segment display and RGB LED feedback for pen size and color selection.

If desired, also include a screenshot of the on-screen result next to a photo of the physical setup.

## 14. Conclusion

JR Paint demonstrates that a custom processor can serve as the control core of a nontrivial interactive FPGA application. The processor executes a substantial assembly program that manages cursor motion, drawing, fill, undo, color selection, pen size, and clear behavior, while dedicated hardware modules handle VGA timing, cursor overlay, PS/2 communication, memory interfaces, and audio playback.

The final system is more than a static display or isolated peripheral demo. It is a complete interactive application with multiple input paths, multiple output paths, software-managed data structures, and a carefully designed hardware/software boundary. That combination is the main technical achievement of the project.
