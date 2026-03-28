# Processor
## Rachel Yu (zy151)

## Description of Design

I made a 5 stage pipelined processor with Fetch, Decode, Execute, Memory, and Writeback. There is a PC and it's incremented by pcAdd, and instructions are passed through the pipeline using registers for each pipeline, such as fdInsn and dxInsn. In the decode stage, the given instruction is separated into opcode and registers fields and the processor can select which register to read from and then the decoder value is latched into the DX stage for execution stage.

During the execute stage, the processor will compute ALU results and other computation such as branch decisions and jump targets and also overflow.

There is also  a separate multdiv part in the processor. In the execute stage, the operands are latched and the processor tracks progress using the pw registers and the md_finish registers. Once the multdiv completes the result is written back to the destination register or r30 for exceptions. 

In the Memory stage, the processor uses the ALU result as the address for data memory during loads and stores. Load data and other results are then passed into the next pipeline register for the final stage.

In the Writeback stage, the processor chooses the final value to write back to the register file which could be the ALU result, loaded memory data, or the multdiv result. If there is an exception, the processor will also write the exception value to r30.

## Bypassing

I used bypassing in execute for both ALU inputs. In my design, dx_opA and dx_opB_raw compare the source registers in D/X against destination registers from later stages and forward the newest value when there is a match. The check goes in the stage order and if there is no match, the processor will use the values already stored in D/X. I did this so that the ALU does not have to wait for normal register writeback when a newer value is already in a later stage.

I also did W to X forwarding after a load stall. After a lw, the loaded value is not ready soon enough for the next cycle in Execute, so I stall once and then let the next instruction get the value from writeback.

## Stalling

In my code, stall_lw goes high when a lw is in D/X and the instruction in F/D needs that destination register. When that happens, I hold Fetch and Decode and write a NOP instruction into D/X.

I also stall for mult/div because those operations take more than one cycle. My code uses stall_md = dx_is_md | md_busy_q, so that the front of the pipeline stops when multiply or divide is starting or still running. Then release_md = md_finish will let my processor know to continue the pipeline once the result is ready.

When a branch or jump is taken, I update the PC to the correct target and send NOP instructions to the wrong path so those instructions do not keep moving through the pipeline.

For mult/div, I use a separate result path into writeback. The mult/div unit runs separately, the result is stored in the pw registers, and then writeback chooses between the normal pipeline result and the mult/div result.

## Optimizations

The main optimization is when I forward the values from the later stages into the execute stage because this allows me to avoid read after write hazards.

Another optimization is that my branches and jumps are resolved in execute so that the processor can get to thew correct PC sooner.

## Bugs
