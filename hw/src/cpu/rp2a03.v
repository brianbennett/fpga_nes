/***************************************************************************************************
** fpga_nes/hw/src/cpu/rp2a03.v
*
*  Copyright (c) 2012, Brian Bennett
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*  Implementation of the RP2A03 chip for an fpga-based NES emulator.  Contains a MOS-6502 CPU
*  core, APU, sprite DMA engine, and joypad control logic.
***************************************************************************************************/

module rp2a03
(
  input  wire        clk_in,         // system clock
  input  wire        rst_in,         // system reset

  // CPU signals.
  input  wire        rdy_in,         // ready signal
  input  wire [ 7:0] d_in,           // data input bus
  input  wire        nnmi_in,        // /nmi interrupt signal (active low)
  input  wire        nres_in,        // /res interrupt signal (active low)
  output wire [ 7:0] d_out,          // data output bus
  output wire [15:0] a_out,          // address bus
  output wire        r_nw_out,       // read/write select (write low)
  output wire        brk_out,        // debug break signal

  // Joypad signals.
  input  wire        jp_data1_in,    // joypad 1 input signal
  input  wire        jp_data2_in,    // joypad 2 input signal
  output wire        jp_clk,         // joypad output clk signal
  output wire        jp_latch,       // joypad output latch signal

  // Audio signals.
  input  wire [ 3:0] mute_in,        // disable autio channels
  output wire        audio_out,      // pwm audio output

  // HCI interface.
  input  wire [ 3:0] dbgreg_sel_in,  // dbg reg select
  input  wire [ 7:0] dbgreg_d_in,    // dbg reg data in
  input  wire        dbgreg_wr_in,   // dbg reg write select
  output wire [ 7:0] dbgreg_d_out    // dbg reg data out
);

//
// CPU: central processing unit block.
//
wire        cpu_ready;
wire [ 7:0] cpu_din;
wire        cpu_nirq;
wire [ 7:0] cpu_dout;
wire [15:0] cpu_a;
wire        cpu_r_nw;

cpu cpu_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .ready_in(cpu_ready),
  .dbgreg_sel_in(dbgreg_sel_in),
  .dbgreg_in(dbgreg_d_in),
  .dbgreg_wr_in(dbgreg_wr_in),
  .d_in(cpu_din),
  .nnmi_in(nnmi_in),
  .nres_in(nres_in),
  .nirq_in(cpu_nirq),
  .d_out(cpu_dout),
  .a_out(cpu_a),
  .r_nw_out(cpu_r_nw),
  .brk_out(brk_out),
  .dbgreg_out(dbgreg_d_out)
);

//
// APU: audio processing unit block.
//
wire [7:0] audio_dout;

apu apu_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .mute_in(mute_in),
  .a_in(cpu_a),
  .d_in(cpu_dout),
  .r_nw_in(cpu_r_nw),
  .audio_out(audio_out),
  .d_out(audio_dout)
);

//
// JP: joypad controller block.
//
wire [7:0] jp_dout;

jp jp_blk(
  .clk(clk_in),
  .rst(rst_in),
  .wr(~cpu_r_nw),
  .addr(cpu_a),
  .din(cpu_dout[0]),
  .jp_data1(jp_data1_in),
  .jp_data2(jp_data2_in),
  .jp_clk(jp_clk),
  .jp_latch(jp_latch),
  .dout(jp_dout)
);

//
// SPRDMA: sprite dma controller block.
//
wire        sprdma_active;
wire [15:0] sprdma_a;
wire [ 7:0] sprdma_dout;
wire        sprdma_r_nw;

sprdma sprdma_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .cpumc_a_in(cpu_a),
  .cpumc_din_in(cpu_dout),
  .cpumc_dout_in(cpu_din),
  .cpu_r_nw_in(cpu_r_nw),
  .active_out(sprdma_active),
  .cpumc_a_out(sprdma_a),
  .cpumc_d_out(sprdma_dout),
  .cpumc_r_nw_out(sprdma_r_nw)
);

assign cpu_ready = rdy_in & !sprdma_active;
assign cpu_din   = d_in | jp_dout | audio_dout;
assign cpu_nirq  = 1'b1;

assign d_out     = (sprdma_active) ? sprdma_dout : cpu_dout;
assign a_out     = (sprdma_active) ? sprdma_a    : cpu_a;
assign r_nw_out  = (sprdma_active) ? sprdma_r_nw : cpu_r_nw;

endmodule

