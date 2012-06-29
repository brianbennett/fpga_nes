/***************************************************************************************************
** fpga_nes/hw/src/cmn/uart/uart_rx.v
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
*  UART receiver.
***************************************************************************************************/

module uart_rx
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
  input  wire                 rx,             // RX transmission wire
  output wire [DATA_BITS-1:0] rx_data,        // Output data
  output wire                 rx_done_tick,   // Output rdy signal
  output wire                 parity_err      // Asserted for one clk on parity error
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
reg [3:0]           q_oversample_tick_cnt, d_oversample_tick_cnt;
reg [DATA_BITS-1:0] q_data, d_data;
reg [2:0]           q_data_bit_idx, d_data_bit_idx;
reg                 q_done_tick, d_done_tick;
reg                 q_parity_err, d_parity_err;
reg                 q_rx;

always @(posedge clk, posedge reset)
  begin
    if (reset)
      begin
        q_state               <= S_IDLE;
        q_oversample_tick_cnt <= 0;
        q_data                <= 0;
        q_data_bit_idx        <= 0;
        q_done_tick           <= 1'b0;
        q_parity_err          <= 1'b0;
        q_rx                  <= 1'b1;
      end
    else
      begin
        q_state               <= d_state;
        q_oversample_tick_cnt <= d_oversample_tick_cnt;
        q_data                <= d_data;
        q_data_bit_idx        <= d_data_bit_idx;
        q_done_tick           <= d_done_tick;
        q_parity_err          <= d_parity_err;
        q_rx                  <= rx;
      end
  end

always @*
  begin
    // Default most state to remain unchanged.
    d_state               = q_state;
    d_data                = q_data;
    d_data_bit_idx        = q_data_bit_idx;

    // Increment the tick counter if the baud_clk counter ticked.
    d_oversample_tick_cnt = (baud_clk_tick) ? q_oversample_tick_cnt + 4'h1 : q_oversample_tick_cnt;

    // Default the done signal and parity err to 0.
    d_done_tick           = 1'b0;
    d_parity_err          = 1'b0;

    case (q_state)
      S_IDLE:
        begin
          // Detect incoming data when rx goes low (start bit).
          if (~q_rx)
            begin
              d_state               = S_START;
              d_oversample_tick_cnt = 0;
            end
        end

      S_START:
        begin
          // Wait for BAUD_CLK_OVERSAMPLE_RATE / 2 ticks to get "centered" in the start bit signal.
          if (baud_clk_tick && (q_oversample_tick_cnt == ((BAUD_CLK_OVERSAMPLE_RATE - 1) / 2)))
            begin
              d_state               = S_DATA;
              d_oversample_tick_cnt = 0;
              d_data_bit_idx        = 0;
            end
        end

      S_DATA:
        begin
          // Every BAUD_CLK_OVERSAMPLE_RATE clocks, sample rx and shift its value into the data reg.
          if (baud_clk_tick && (q_oversample_tick_cnt == (BAUD_CLK_OVERSAMPLE_RATE - 1)))
            begin
              d_data                = { q_rx, q_data[DATA_BITS-1:1] };
              d_oversample_tick_cnt = 0;

              if (q_data_bit_idx == (DATA_BITS - 1))
                begin
                  if (PARITY_MODE == 0)
                    d_state = S_STOP;
                  else
                    d_state = S_PARITY;
                end
              else
                d_data_bit_idx = q_data_bit_idx + 3'h1;
            end
        end

      S_PARITY:
        begin
          if (baud_clk_tick && (q_oversample_tick_cnt == (BAUD_CLK_OVERSAMPLE_RATE - 1)))
            begin
              if (PARITY_MODE == 1)
                d_parity_err = (q_rx != ~^q_data);
              else
                d_parity_err = (q_rx != ^q_data);

              d_state               = S_STOP;
              d_oversample_tick_cnt = 0;
            end
        end

      S_STOP:
        begin
          // Wait for stop bit before returning to idle.  Signal done_tick.
          if (baud_clk_tick && (q_oversample_tick_cnt == STOP_OVERSAMPLE_TICKS - 1))
            begin
              d_state     = S_IDLE;
              d_done_tick = 1'b1;
            end
        end
    endcase
end

assign rx_data      = q_data;
assign rx_done_tick = q_done_tick;
assign parity_err   = q_parity_err;

endmodule

