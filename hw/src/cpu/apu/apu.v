/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu.v
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
*  Audio Processing Unit.
***************************************************************************************************/

module apu
(
  input  wire        clk_in,    // system clock signal
  input  wire        rst_in,    // reset signal
  input  wire [ 3:0] mute_in,   // disable specific audio channels
  input  wire [15:0] a_in,      // addr input bus
  input  wire [ 7:0] d_in,      // data input bus
  input  wire        r_nw_in,   // read/write select
  output wire        audio_out, // pwm audio output
  output wire [ 7:0] d_out      // data output bus
);

localparam [15:0] PULSE0_CHANNEL_CNTL_MMR_ADDR   = 16'h4000;
localparam [15:0] PULSE1_CHANNEL_CNTL_MMR_ADDR   = 16'h4004;
localparam [15:0] TRIANGLE_CHANNEL_CNTL_MMR_ADDR = 16'h4008;
localparam [15:0] NOISE_CHANNEL_CNTL_MMR_ADDR    = 16'h400C;
localparam [15:0] STATUS_MMR_ADDR                = 16'h4015;
localparam [15:0] FRAME_COUNTER_CNTL_MMR_ADDR    = 16'h4017;

// CPU cycle pulse.  Ideally this would be generated in rp2a03 and shared by the apu and cpu.
reg  [5:0] q_clk_cnt;
wire [5:0] d_clk_cnt;
wire       cpu_cycle_pulse;
wire       apu_cycle_pulse;
wire       e_pulse;
wire       l_pulse;
wire       f_pulse;
reg        q_pulse0_en;
wire       d_pulse0_en;
reg        q_pulse1_en;
wire       d_pulse1_en;
reg        q_triangle_en;
wire       d_triangle_en;
reg        q_noise_en;
wire       d_noise_en;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_clk_cnt     <= 6'h00;
        q_pulse0_en   <= 1'b0;
        q_pulse1_en   <= 1'b0;
        q_triangle_en <= 1'b0;
        q_noise_en    <= 1'b0;
      end
    else
      begin
        q_clk_cnt     <= d_clk_cnt;
        q_pulse0_en   <= d_pulse0_en;
        q_pulse1_en   <= d_pulse1_en;
        q_triangle_en <= d_triangle_en;
        q_noise_en    <= d_noise_en;
      end
  end

assign d_clk_cnt     = (q_clk_cnt == 6'h37) ? 6'h00 : q_clk_cnt + 6'h01;
assign d_pulse0_en   = (~r_nw_in && (a_in == STATUS_MMR_ADDR)) ? d_in[0] : q_pulse0_en;
assign d_pulse1_en   = (~r_nw_in && (a_in == STATUS_MMR_ADDR)) ? d_in[1] : q_pulse1_en;
assign d_triangle_en = (~r_nw_in && (a_in == STATUS_MMR_ADDR)) ? d_in[2] : q_triangle_en;
assign d_noise_en    = (~r_nw_in && (a_in == STATUS_MMR_ADDR)) ? d_in[3] : q_noise_en;

assign cpu_cycle_pulse = (q_clk_cnt == 6'h00);


apu_div #(.PERIOD_BITS(1)) apu_pulse_gen(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .pulse_in(cpu_cycle_pulse),
  .reload_in(1'b0),
  .period_in(1'b1),
  .pulse_out(apu_cycle_pulse)
);

//
// Frame counter.
//
wire frame_counter_mode_wr;

apu_frame_counter apu_frame_counter_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .cpu_cycle_pulse_in(cpu_cycle_pulse),
  .apu_cycle_pulse_in(apu_cycle_pulse),
  .mode_in(d_in[7:6]),
  .mode_wr_in(frame_counter_mode_wr),
  .e_pulse_out(e_pulse),
  .l_pulse_out(l_pulse),
  .f_pulse_out(f_pulse)
);

assign frame_counter_mode_wr = ~r_nw_in && (a_in == FRAME_COUNTER_CNTL_MMR_ADDR);

//
// Pulse 0 channel.
//
wire [3:0] pulse0_out;
wire       pulse0_active;
wire       pulse0_wr;

apu_pulse #(.CHANNEL(0)) apu_pulse0_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(q_pulse0_en),
  .cpu_cycle_pulse_in(cpu_cycle_pulse),
  .lc_pulse_in(l_pulse),
  .eg_pulse_in(e_pulse),
  .a_in(a_in[1:0]),
  .d_in(d_in),
  .wr_in(pulse0_wr),
  .pulse_out(pulse0_out),
  .active_out(pulse0_active)
);

assign pulse0_wr = ~r_nw_in && (a_in[15:2] == PULSE0_CHANNEL_CNTL_MMR_ADDR[15:2]);

//
// Pulse 1 channel.
//
wire [3:0] pulse1_out;
wire       pulse1_active;
wire       pulse1_wr;

apu_pulse #(.CHANNEL(1)) apu_pulse1_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(q_pulse1_en),
  .cpu_cycle_pulse_in(cpu_cycle_pulse),
  .lc_pulse_in(l_pulse),
  .eg_pulse_in(e_pulse),
  .a_in(a_in[1:0]),
  .d_in(d_in),
  .wr_in(pulse1_wr),
  .pulse_out(pulse1_out),
  .active_out(pulse1_active)
);

assign pulse1_wr = ~r_nw_in && (a_in[15:2] == PULSE1_CHANNEL_CNTL_MMR_ADDR[15:2]);

//
// Triangle channel.
//
wire [3:0] triangle_out;
wire       triangle_active;
wire       triangle_wr;

apu_triangle apu_triangle_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(q_triangle_en),
  .cpu_cycle_pulse_in(cpu_cycle_pulse),
  .lc_pulse_in(l_pulse),
  .eg_pulse_in(e_pulse),
  .a_in(a_in[1:0]),
  .d_in(d_in),
  .wr_in(triangle_wr),
  .triangle_out(triangle_out),
  .active_out(triangle_active)
);

assign triangle_wr = ~r_nw_in && (a_in[15:2] == TRIANGLE_CHANNEL_CNTL_MMR_ADDR[15:2]);

//
// Noise channel.
//
wire [3:0] noise_out;
wire       noise_active;
wire       noise_wr;

apu_noise apu_noise_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(q_noise_en),
  .apu_cycle_pulse_in(apu_cycle_pulse),
  .lc_pulse_in(l_pulse),
  .eg_pulse_in(e_pulse),
  .a_in(a_in[1:0]),
  .d_in(d_in),
  .wr_in(noise_wr),
  .noise_out(noise_out),
  .active_out(noise_active)
);

assign noise_wr = ~r_nw_in && (a_in[15:2] == NOISE_CHANNEL_CNTL_MMR_ADDR[15:2]);

//
// Mixer.
//
apu_mixer apu_mixer_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .mute_in(mute_in),
  .pulse0_in(pulse0_out),
  .pulse1_in(pulse1_out),
  .triangle_in(triangle_out),
  .noise_in(noise_out),
  .audio_out(audio_out)
);

assign d_out = (r_nw_in && (a_in == STATUS_MMR_ADDR)) ?
               { 4'b0000, noise_active, triangle_active, pulse1_active, pulse0_active } : 8'h00;

endmodule

