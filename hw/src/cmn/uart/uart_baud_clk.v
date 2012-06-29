/***************************************************************************************************
** fpga_nes/hw/src/cmn/uart/uart_baud_clk.v
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
*  Generates a tick signal at OVERSAMPLE_RATE times the baud rate.  Should be fed to the uart_rx
*  and uart_tx blocks.
***************************************************************************************************/

module uart_baud_clk
#(
  parameter SYS_CLK_FREQ             = 50000000,
  parameter BAUD                     = 19200,
  parameter BAUD_CLK_OVERSAMPLE_RATE = 16
)
(
  input  wire clk,
  input  wire reset,
  output wire baud_clk_tick
);

localparam [15:0] CLKS_PER_OVERSAMPLE_TICK = (SYS_CLK_FREQ / BAUD) / BAUD_CLK_OVERSAMPLE_RATE;

// Registers
reg  [15:0] q_cnt;
wire [15:0] d_cnt;

always @(posedge clk, posedge reset)
  begin
    if (reset)
      q_cnt <= 0;
    else
      q_cnt <= d_cnt;
  end

assign d_cnt         = (q_cnt == (CLKS_PER_OVERSAMPLE_TICK - 1)) ? 16'h0000 : (q_cnt + 16'h0001);
assign baud_clk_tick = (q_cnt == (CLKS_PER_OVERSAMPLE_TICK - 1)) ? 1'b1     : 1'b0;

endmodule

