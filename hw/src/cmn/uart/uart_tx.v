/***************************************************************************************************
** fpga_nes/hw/src/cmn/uart/uart_tx.v
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
*  UART transmitter.
***************************************************************************************************/

module uart_tx
#(
  parameter DATA_BITS                = 8,
  parameter STOP_BITS                = 1,
  parameter PARITY_MODE              = 1, // 0 = NONE, 1 = ODD, 2 = EVEN
  parameter BAUD_CLK_OVERSAMPLE_RATE = 16
)
(
  input  wire                 clk,            // System clock
  input  wire                 reset,          // Reset signal
  input  wire                 baud_clk_tick,  // 1 tick per OVERSAMPLE_RATE baud clks
  input  wire                 tx_start,       // Signal requesting trasmission start
  input  wire [DATA_BITS-1:0] tx_data,        // Data to be transmitted
  output wire                 tx_done_tick,   // Transfer done signal
  output wire                 tx              // TX transmission wire
);

localparam [5:0] STOP_OVERSAMPLE_TICKS = STOP_BITS * BAUD_CLK_OVERSAMPLE_RATE;

// Symbolic state representations.
localparam [4:0] S_IDLE   = 5'h01,
                 S_START  = 5'h02,
                 S_DATA   = 5'h04,
                 S_PARITY = 5'h08,
                 S_STOP   = 5'h10;

// Registers
reg [4:0]           q_state, d_state;
reg [3:0]           q_baud_clk_tick_cnt, d_baud_clk_tick_cnt;
reg [DATA_BITS-1:0] q_data, d_data;
reg [2:0]           q_data_bit_idx, d_data_bit_idx;
reg                 q_parity_bit, d_parity_bit;
reg                 q_tx, d_tx;
reg                 q_tx_done_tick, d_tx_done_tick;

always @(posedge clk, posedge reset)
  begin
    if (reset)
      begin
        q_state             <= S_IDLE;
        q_baud_clk_tick_cnt <= 0;
        q_data              <= 0;
        q_data_bit_idx      <= 0;
        q_tx                <= 1'b1;
        q_tx_done_tick      <= 1'b0;
        q_parity_bit        <= 1'b0;
      end
    else
      begin
        q_state             <= d_state;
        q_baud_clk_tick_cnt <= d_baud_clk_tick_cnt;
        q_data              <= d_data;
        q_data_bit_idx      <= d_data_bit_idx;
        q_tx                <= d_tx;
        q_tx_done_tick      <= d_tx_done_tick;
        q_parity_bit        <= d_parity_bit;
      end
  end

always @*
  begin
    // Default most state to remain unchanged.
    d_state             = q_state;
    d_data              = q_data;
    d_data_bit_idx      = q_data_bit_idx;
    d_parity_bit        = q_parity_bit;

    // Increment the tick counter if the baud clk counter ticked.
    d_baud_clk_tick_cnt = (baud_clk_tick) ? (q_baud_clk_tick_cnt + 4'h1) : q_baud_clk_tick_cnt;

    d_tx_done_tick = 1'b0;
    d_tx           = 1'b1;

    case (q_state)
      S_IDLE:
        begin
          // Detect tx_start signal from client, latch data, and begin transmission.  Don't latch
          // during done_tick.
          if (tx_start && ~q_tx_done_tick)
            begin
              d_state             = S_START;
              d_baud_clk_tick_cnt = 0;
              d_data              = tx_data;

              if (PARITY_MODE == 1)
                d_parity_bit = ~^tx_data;
              else if (PARITY_MODE == 2)
                d_parity_bit = ~tx_data;
            end
        end

      S_START:
        begin
          // Send low signal to indicate start bit.  When done, move to data transmission.
          d_tx = 1'b0;
          if (baud_clk_tick && (q_baud_clk_tick_cnt == (BAUD_CLK_OVERSAMPLE_RATE - 1)))
            begin
              d_state             = S_DATA;
              d_baud_clk_tick_cnt = 0;
              d_data_bit_idx      = 0;
            end
        end

      S_DATA:
        begin
          // Transmit current low data bit.  After OVERSAMPLE_RATE ticks, shift the data reg
          // and move on to the next bit.  After DATA_BITS bits, move to stop bit state.
          d_tx = q_data[0];
          if (baud_clk_tick && (q_baud_clk_tick_cnt == (BAUD_CLK_OVERSAMPLE_RATE - 1)))
            begin
              d_data              = q_data >> 1;
              d_data_bit_idx      = q_data_bit_idx + 3'h1;
              d_baud_clk_tick_cnt = 0;

              if (q_data_bit_idx == (DATA_BITS - 1))
                begin
                  if (PARITY_MODE == 0)
                    d_state = S_STOP;
                  else
                    d_state = S_PARITY;
                end
            end
        end

      S_PARITY:
        begin
          // Send parity bit.
          d_tx = q_parity_bit;
          if (baud_clk_tick && (q_baud_clk_tick_cnt == (BAUD_CLK_OVERSAMPLE_RATE - 1)))
            begin
              d_state             = S_STOP;
              d_baud_clk_tick_cnt = 0;
            end
        end

      S_STOP:
        begin
          // Issue stop bit.
          if (baud_clk_tick && (q_baud_clk_tick_cnt == (STOP_OVERSAMPLE_TICKS - 1)))
            begin
              d_state        = S_IDLE;
              d_tx_done_tick = 1'b1;
            end
        end
    endcase
end

assign tx           = q_tx;
assign tx_done_tick = q_tx_done_tick;

endmodule

