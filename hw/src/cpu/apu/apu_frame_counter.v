/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu_frame_counter.v
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
*  APU frame counter sub-block.
***************************************************************************************************/

module apu_frame_counter
(
  input  wire       clk_in,              // system clock signal
  input  wire       rst_in,              // reset signal
  input  wire       cpu_cycle_pulse_in,  // 1 clk pulse on every cpu cycle
  input  wire       apu_cycle_pulse_in,  // 1 clk pulse on every apu cycle
  input  wire [1:0] mode_in,             // mode ([0] = IRQ inhibit, [1] = sequence mode)
  input  wire       mode_wr_in,          // update mode
  output reg        e_pulse_out,         // envelope and linear counter pulse (~240 Hz)
  output reg        l_pulse_out,         // length counter and sweep pulse (~120 Hz)
  output reg        f_pulse_out          // frame pulse (~60Hz, should drive IRQ)
);

reg [14:0] q_apu_cycle_cnt, d_apu_cycle_cnt;
reg        q_seq_mode,      d_seq_mode;
reg        q_irq_inhibit,   d_irq_inhibit;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_apu_cycle_cnt <= 15'h0000;
        q_seq_mode      <= 1'b0;
        q_irq_inhibit   <= 1'b0;
      end
    else
      begin
        q_apu_cycle_cnt <= d_apu_cycle_cnt;
        q_seq_mode      <= d_seq_mode;
        q_irq_inhibit   <= d_irq_inhibit;
      end
  end

always @*
  begin
    d_apu_cycle_cnt = q_apu_cycle_cnt;
    d_seq_mode      = (mode_wr_in) ? mode_in[1] : q_seq_mode;
    d_irq_inhibit   = (mode_wr_in) ? mode_in[0] : q_irq_inhibit;

    e_pulse_out = 1'b0;
    l_pulse_out = 1'b0;
    f_pulse_out = 1'b0;

    if (apu_cycle_pulse_in)
      begin
        d_apu_cycle_cnt = q_apu_cycle_cnt + 15'h0001;

        if ((q_apu_cycle_cnt == 15'h0E90) || (q_apu_cycle_cnt == 15'h2BB1))
          begin
            e_pulse_out = 1'b1;
          end
        else if (q_apu_cycle_cnt == 15'h1D20)
          begin
            e_pulse_out = 1'b1;
            l_pulse_out = 1'b1;
          end
        else if (!q_seq_mode && (q_apu_cycle_cnt == 15'h3A42))
          begin
            e_pulse_out = 1'b1;
            l_pulse_out = 1'b1;
            f_pulse_out = ~q_irq_inhibit;

            d_apu_cycle_cnt = 15'h0000;
          end
        else if ((q_apu_cycle_cnt == 15'h48d0))
          begin
            e_pulse_out = q_seq_mode;
            l_pulse_out = q_seq_mode;

            d_apu_cycle_cnt = 15'h0000;
          end
      end

      if (cpu_cycle_pulse_in && mode_wr_in)
        d_apu_cycle_cnt = 15'h48d0;
  end

endmodule

