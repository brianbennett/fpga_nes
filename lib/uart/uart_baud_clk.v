///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_baud_clk
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 06/27/2010
//
// Description:
// 
// Generates a tick signal at OVERSAMPLE_RATE times the baud rate.  Should be fed to the uart_rx
// and uart_tx blocks.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
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

