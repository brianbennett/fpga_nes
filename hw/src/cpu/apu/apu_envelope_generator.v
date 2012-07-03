/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu_envelope_generator.v
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
*  APU length counter; building block used by several other APU components.  Provides automatic
*  duration control for the NES APU waveform channels. Once loaded with a value, it can optionally
*  count down and silence the channel when it reaches zero.
***************************************************************************************************/

module apu_envelope_generator
(
  input  wire       clk_in,       // system clock signal
  input  wire       rst_in,       // reset signal
  input  wire       eg_pulse_in,  // 1 clk pulse for every env gen update
  input  wire [5:0] env_in,       // envelope value (e.g., via $4000)
  input  wire       env_wr_in,    // envelope value write
  input  wire       env_restart,  // envelope restart
  output wire [3:0] env_out       // output volume
);

reg  [5:0] q_reg;
wire [5:0] d_reg;
reg  [3:0] q_cnt,        d_cnt;
reg        q_start_flag, d_start_flag;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_reg        <= 6'h00;
        q_cnt        <= 4'h0;
        q_start_flag <= 1'b0;
      end
    else
      begin
        q_reg        <= d_reg;
        q_cnt        <= d_cnt;
        q_start_flag <= d_start_flag;
      end
  end

reg  divider_pulse_in;
reg  divider_reload;
wire divider_pulse_out;

apu_div #(.PERIOD_BITS(4)) divider(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .pulse_in(divider_pulse_in),
  .reload_in(divider_reload),
  .period_in(q_reg[3:0]),
  .pulse_out(divider_pulse_out)
);

always @*
  begin
    d_cnt        = q_cnt;
    d_start_flag = q_start_flag;

    divider_pulse_in = 1'b0;
    divider_reload   = 1'b0;

    // When the divider outputs a clock, one of two actions occurs: If the counter is non-zero, it
    // is decremented, otherwise if the loop flag is set, the counter is loaded with 15.
    if (divider_pulse_out)
      begin
        divider_reload = 1'b1;

        if (q_cnt != 4'h0)
          d_cnt = q_cnt - 4'h1;
        else if (q_reg[5])
          d_cnt = 4'hF;
      end

    // When clocked by the frame counter, one of two actions occurs: if the start flag is clear,
    // the divider is clocked, otherwise the start flag is cleared, the counter is loaded with 15,
    // and the divider's period is immediately reloaded.
    if (eg_pulse_in)
      begin
        if (q_start_flag == 1'b0)
          begin
            divider_pulse_in = 1'b1;
          end
        else
          begin
            d_start_flag = 1'b0;
            d_cnt        = 4'hF;
          end
      end

    if (env_restart)
      d_start_flag = 1'b1;
  end

assign d_reg = (env_wr_in) ? env_in : q_reg;

// The envelope unit's volume output depends on the constant volume flag: if set, the envelope
// parameter directly sets the volume, otherwise the counter's value is the current volume.
assign env_out = (q_reg[4]) ? q_reg[3:0] : q_cnt;

endmodule

