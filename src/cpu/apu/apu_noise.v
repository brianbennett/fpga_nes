/***************************************************************************************************
** fpga_nes/src/cpu/apu/apu_noise.v
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
*  APU noise channel.
***************************************************************************************************/

module apu_noise
(
  input  wire       clk_in,              // system clock signal
  input  wire       rst_in,              // reset signal
  input  wire       en_in,               // enable (via $4015)
  input  wire       apu_cycle_pulse_in,  // 1 clk pulse on every apu cycle
  input  wire       lc_pulse_in,         // 1 clk pulse for every length counter decrement
  input  wire       eg_pulse_in,         // 1 clk pulse for every env gen update
  input  wire [1:0] a_in,                // control register addr (i.e. $400C - $400F)
  input  wire [7:0] d_in,                // control register write value
  input  wire       wr_in,               // enable control register write
  output wire [3:0] noise_out,           // noise channel output
  output wire       active_out           // noise channel active (length counter > 0)
);

reg  [14:0] q_lfsr;
wire [14:0] d_lfsr;
reg         q_mode;
wire        d_mode;
reg         q_length_counter_halt;
wire        d_length_counter_halt;
reg  [ 3:0] q_env;
wire [ 3:0] d_env;

wire [11:0] timer_period;
wire        timer_period_wr;
wire        timer_pulse;

apu_div #(.PERIOD_BITS(12),
          .INIT_PERIOD(4)) timer(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .pulse_in(apu_cycle_pulse_in),
  .set_period_in(timer_period_wr),
  .period_in(timer_period),
  .pulse_out(timer_pulse)
);

assign timer_period_wr = wr_in && (a_in == 2'b10);
assign timer_period = (d_in[3:0] == 4'h0) ? 12'h004 :
                      (d_in[3:0] == 4'h1) ? 12'h008 :
                      (d_in[3:0] == 4'h2) ? 12'h010 :
                      (d_in[3:0] == 4'h3) ? 12'h020 :
                      (d_in[3:0] == 4'h4) ? 12'h040 :
                      (d_in[3:0] == 4'h5) ? 12'h060 :
                      (d_in[3:0] == 4'h6) ? 12'h080 :
                      (d_in[3:0] == 4'h7) ? 12'h0A0 :
                      (d_in[3:0] == 4'h8) ? 12'h0CA :
                      (d_in[3:0] == 4'h9) ? 12'h0FE :
                      (d_in[3:0] == 4'hA) ? 12'h17C :
                      (d_in[3:0] == 4'hB) ? 12'h1FC :
                      (d_in[3:0] == 4'hC) ? 12'h2FA :
                      (d_in[3:0] == 4'hD) ? 12'h3F8 :
                      (d_in[3:0] == 4'hE) ? 12'h7F2 :
                                            12'hFE4;

wire length_counter_wr;
wire length_counter_en;

apu_length_counter length_counter(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(en_in),
  .halt_in(q_length_counter_halt),
  .length_pulse_in(lc_pulse_in),
  .length_in(d_in[7:3]),
  .length_wr_in(length_counter_wr),
  .en_out(length_counter_en)
);

assign length_counter_wr = wr_in && (a_in == 2'b11);

wire       envelope_generator_wr;
wire       envelope_generator_restart;
wire [3:0] envelope_generator_out;

apu_envelope_generator envelope_generator(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .eg_pulse_in(eg_pulse_in),
  .env_in(d_in[5:0]),
  .env_wr_in(envelope_generator_wr),
  .env_restart(envelope_generator_restart),
  .env_out(envelope_generator_out)
);

assign envelope_generator_wr      = wr_in && (a_in == 2'b00);
assign envelope_generator_restart = wr_in && (a_in == 2'b11);

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_lfsr                <= 15'h0001;
        q_mode                <= 1'b0;
        q_length_counter_halt <= 1'b0;
      end
    else
      begin
        q_lfsr                <= d_lfsr;
        q_mode                <= d_mode;
        q_length_counter_halt <= d_length_counter_halt;
      end
  end

assign d_lfsr = (timer_pulse) ? { q_lfsr[0] ^ ((q_mode) ? q_lfsr[6] : q_lfsr[1]), q_lfsr[14:1] } :
                                q_lfsr;

assign d_mode                = (wr_in && (a_in == 2'b10)) ? d_in[7]   : q_mode;
assign d_length_counter_halt = (wr_in && (a_in == 2'b00)) ? d_in[5]   : q_length_counter_halt;

assign noise_out  = (q_lfsr[0] && length_counter_en) ? envelope_generator_out : 4'h0;
assign active_out = length_counter_en;

endmodule

