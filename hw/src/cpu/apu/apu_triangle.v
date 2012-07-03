/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu_triangle.v
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
*  APU triangle channel.
***************************************************************************************************/

module apu_triangle
(
  input  wire       clk_in,              // system clock signal
  input  wire       rst_in,              // reset signal
  input  wire       en_in,               // enable (via $4015)
  input  wire       cpu_cycle_pulse_in,  // 1 clk pulse on every cpu cycle
  input  wire       lc_pulse_in,         // 1 clk pulse for every length counter decrement
  input  wire       eg_pulse_in,         // 1 clk pulse for every env gen update
  input  wire [1:0] a_in,                // control register addr (i.e. $400C - $400F)
  input  wire [7:0] d_in,                // control register write value
  input  wire       wr_in,               // enable control register write
  output wire [3:0] triangle_out,        // triangle channel output
  output wire       active_out           // triangle channel active (length counter > 0)
);

//
// Timer
//
reg  [10:0] q_timer_period;
wire [10:0] d_timer_period;
wire        timer_pulse;

always @(posedge clk_in)
  begin
    if (rst_in)
      q_timer_period <= 11'h000;
    else
      q_timer_period <= d_timer_period;
  end

apu_div #(.PERIOD_BITS(11)) timer(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .pulse_in(cpu_cycle_pulse_in),
  .reload_in(1'b0),
  .period_in(q_timer_period),
  .pulse_out(timer_pulse)
);

assign d_timer_period = (wr_in && (a_in == 2'b10)) ? { q_timer_period[10:8], d_in[7:0] } :
                        (wr_in && (a_in == 2'b11)) ? { d_in[2:0], q_timer_period[7:0] }  :
                                                     q_timer_period;

//
// Linear Counter
//
reg        q_linear_counter_halt;
wire       d_linear_counter_halt;
reg  [7:0] q_linear_counter_cntl;
wire [7:0] d_linear_counter_cntl;
reg  [6:0] q_linear_counter_val;
wire [6:0] d_linear_counter_val;
wire       linear_counter_en;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_linear_counter_halt <= 1'b0;
        q_linear_counter_cntl <= 8'h00;
        q_linear_counter_val  <= 7'h00;
      end
    else
      begin
        q_linear_counter_halt <= d_linear_counter_halt;
        q_linear_counter_cntl <= d_linear_counter_cntl;
        q_linear_counter_val  <= d_linear_counter_val;
      end
  end

assign d_linear_counter_cntl = (wr_in && (a_in == 2'b00)) ? d_in : q_linear_counter_cntl;

assign d_linear_counter_val =
  (eg_pulse_in && q_linear_counter_halt)           ? q_linear_counter_cntl[6:0]   :
  (eg_pulse_in && (q_linear_counter_val != 7'h00)) ? q_linear_counter_val - 7'h01 :
                                                     q_linear_counter_val;

assign d_linear_counter_halt =
  (wr_in && (a_in == 2'b11))                 ? 1'b1 :
  (eg_pulse_in && !q_linear_counter_cntl[7]) ? 1'b0 :
                                               q_linear_counter_halt;

assign linear_counter_en = |q_linear_counter_val;

//
// Length Counter
//
reg  q_length_counter_halt;
wire d_length_counter_halt;

wire length_counter_wr;
wire length_counter_en;

always @(posedge clk_in)
  begin
    if (rst_in)
      q_length_counter_halt <= 1'b0;
    else
      q_length_counter_halt <= d_length_counter_halt;
  end

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

assign d_length_counter_halt = (wr_in && (a_in == 2'b00)) ? d_in[7] : q_length_counter_halt;
assign length_counter_wr     = wr_in && (a_in == 2'b11);

//
// Sequencer
//
reg  [4:0] q_seq;
wire [4:0] d_seq;
wire [3:0] seq_out;

always @(posedge clk_in)
  begin
    if (rst_in)
      q_seq <= 5'h0;
    else
      q_seq <= d_seq;
  end

assign d_seq   = (active_out && timer_pulse) ? q_seq + 5'h01 : q_seq;
assign seq_out = (q_seq[4]) ? q_seq[3:0] : ~q_seq[3:0];

assign active_out   = linear_counter_en && length_counter_en;
assign triangle_out = seq_out;

endmodule

