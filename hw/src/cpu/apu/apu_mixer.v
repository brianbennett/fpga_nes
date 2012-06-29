/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu_mixer.v
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
*  APU mixer.
***************************************************************************************************/

module apu_mixer
(
  input  wire       clk_in,     // system clock signal
  input  wire       rst_in,     // reset signal
  input  wire       mute_in,    // mute all channels
  input  wire [3:0] pulse0_in,  // pulse 0 channel input
  input  wire [3:0] pulse1_in,  // pulse 1 channel input
  input  wire [3:0] noise_in,   // noise channel input
  output wire       audio_out   // mixed audio output
);

reg [5:0] mixed_out;
reg [5:0] pulse_out;
reg [5:0] tnd_out;
reg [4:0] pulse_in_total;

always @*
  begin
    pulse_in_total = pulse0_in + pulse1_in;

    case (pulse_in_total)
      5'h00:   pulse_out = 6'h00;
      5'h01:   pulse_out = 6'h01;
      5'h02:   pulse_out = 6'h01;
      5'h03:   pulse_out = 6'h02;
      5'h04:   pulse_out = 6'h03;
      5'h05:   pulse_out = 6'h03;
      5'h06:   pulse_out = 6'h04;
      5'h07:   pulse_out = 6'h05;
      5'h08:   pulse_out = 6'h05;
      5'h09:   pulse_out = 6'h06;
      5'h0A:   pulse_out = 6'h07;
      5'h0B:   pulse_out = 6'h07;
      5'h0C:   pulse_out = 6'h08;
      5'h0D:   pulse_out = 6'h08;
      5'h0E:   pulse_out = 6'h09;
      5'h0F:   pulse_out = 6'h09;
      5'h10:   pulse_out = 6'h0A;
      5'h11:   pulse_out = 6'h0A;
      5'h12:   pulse_out = 6'h0B;
      5'h13:   pulse_out = 6'h0B;
      5'h14:   pulse_out = 6'h0C;
      5'h15:   pulse_out = 6'h0C;
      5'h16:   pulse_out = 6'h0D;
      5'h17:   pulse_out = 6'h0D;
      5'h18:   pulse_out = 6'h0E;
      5'h19:   pulse_out = 6'h0E;
      5'h1A:   pulse_out = 6'h0F;
      5'h1B:   pulse_out = 6'h0F;
      5'h1C:   pulse_out = 6'h0F;
      5'h1D:   pulse_out = 6'h10;
      5'h1E:   pulse_out = 6'h10;
      default: pulse_out = 6'bxxxxxx;
    endcase

    case (noise_in)
      4'h0: tnd_out = 6'h00;
      4'h1: tnd_out = 6'h01;
      4'h2: tnd_out = 6'h02;
      4'h3: tnd_out = 6'h02;
      4'h4: tnd_out = 6'h03;
      4'h5: tnd_out = 6'h04;
      4'h6: tnd_out = 6'h05;
      4'h7: tnd_out = 6'h06;
      4'h8: tnd_out = 6'h06;
      4'h9: tnd_out = 6'h07;
      4'hA: tnd_out = 6'h08;
      4'hB: tnd_out = 6'h09;
      4'hC: tnd_out = 6'h09;
      4'hD: tnd_out = 6'h0A;
      4'hE: tnd_out = 6'h0B;
      4'hF: tnd_out = 6'h0B;
    endcase

    mixed_out = pulse_out + tnd_out;
  end

//
// Pulse width modulation.
//
reg  [5:0] q_pwm_cnt;
wire [5:0] d_pwm_cnt;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_pwm_cnt  <= 6'h0;
      end
    else
      begin
        q_pwm_cnt  <= d_pwm_cnt;
      end
  end

assign d_pwm_cnt = q_pwm_cnt + 4'h1;

assign audio_out = (mute_in) ? 1'b0 : (mixed_out > q_pwm_cnt);

endmodule

