/***************************************************************************************************
** fpga_nes/hw/src/cmn/uart/uart.v
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
*  UART controller.  Universal Asynchronous Receiver/Transmitter control module for an RS-232
*  (serial) port.
***************************************************************************************************/

`include "uart_baud_clk.v"
`include "uart_rx.v"
`include "uart_tx.v"

`include "../fifo/fifo.v"

module uart
#(
  parameter SYS_CLK_FREQ = 50000000,
  parameter BAUD_RATE    = 19200,
  parameter DATA_BITS    = 8,
  parameter STOP_BITS    = 1,
  parameter PARITY_MODE  = 0  // 0 = none, 1 = odd, 2 = even
)
(
  input  wire                 clk,        // System clk
  input  wire                 reset,      // Reset signal
  input  wire                 rx,         // RS-232 rx pin
  input  wire [DATA_BITS-1:0] tx_data,    // Data to be transmitted when wr_en is 1
  input  wire                 rd_en,      // Pops current read FIFO front off the queue
  input  wire                 wr_en,      // Write tx_data over serial connection
  output wire                 tx,         // RS-232 tx pin
  output wire [DATA_BITS-1:0] rx_data,    // Data currently at front of read FIFO
  output wire                 rx_empty,   // 1 if there is no more read data available
  output wire                 tx_full,    // 1 if the transmit FIFO cannot accept more requests
  output wire                 parity_err  // 1 if a parity error has been detected
);

localparam BAUD_CLK_OVERSAMPLE_RATE = 16;

wire                 baud_clk_tick;

wire [DATA_BITS-1:0] rx_fifo_wr_data;
wire                 rx_done_tick;
wire                 rx_parity_err;

wire [DATA_BITS-1:0] tx_fifo_rd_data;
wire                 tx_done_tick;
wire                 tx_fifo_empty;

// Store parity error in a flip flop as persistent state.
reg  q_rx_parity_err;
wire d_rx_parity_err;

always @(posedge clk, posedge reset)
  begin
    if (reset)
      q_rx_parity_err <= 1'b0;
    else
      q_rx_parity_err <= d_rx_parity_err;
  end

assign parity_err      = q_rx_parity_err;
assign d_rx_parity_err = q_rx_parity_err || rx_parity_err;

// BAUD clock module
uart_baud_clk #(.SYS_CLK_FREQ(SYS_CLK_FREQ),
                .BAUD(BAUD_RATE),
                .BAUD_CLK_OVERSAMPLE_RATE(BAUD_CLK_OVERSAMPLE_RATE)) uart_baud_clk_blk
(
  .clk(clk),
  .reset(reset),
  .baud_clk_tick(baud_clk_tick)
);

// RX (receiver) module
uart_rx #(.DATA_BITS(DATA_BITS),
          .STOP_BITS(STOP_BITS),
          .PARITY_MODE(PARITY_MODE),
          .BAUD_CLK_OVERSAMPLE_RATE(BAUD_CLK_OVERSAMPLE_RATE)) uart_rx_blk
(
  .clk(clk),
  .reset(reset),
  .baud_clk_tick(baud_clk_tick),
  .rx(rx),
  .rx_data(rx_fifo_wr_data),
  .rx_done_tick(rx_done_tick),
  .parity_err(rx_parity_err)
);

// TX (transmitter) module
uart_tx #(.DATA_BITS(DATA_BITS),
          .STOP_BITS(STOP_BITS),
          .PARITY_MODE(PARITY_MODE),
          .BAUD_CLK_OVERSAMPLE_RATE(BAUD_CLK_OVERSAMPLE_RATE)) uart_tx_blk
(
  .clk(clk),
  .reset(reset),
  .baud_clk_tick(baud_clk_tick),
  .tx_start(~tx_fifo_empty),
  .tx_data(tx_fifo_rd_data),
  .tx_done_tick(tx_done_tick),
  .tx(tx)
);

// RX FIFO
fifo #(.DATA_BITS(DATA_BITS),
       .ADDR_BITS(3)) uart_rx_fifo
(
  .clk(clk),
  .reset(reset),
  .rd_en(rd_en),
  .wr_en(rx_done_tick),
  .wr_data(rx_fifo_wr_data),
  .rd_data(rx_data),
  .empty(rx_empty),
  .full()
);

// TX FIFO
fifo #(.DATA_BITS(DATA_BITS),
       .ADDR_BITS(3)) uart_tx_fifo
(
  .clk(clk),
  .reset(reset),
  .rd_en(tx_done_tick),
  .wr_en(wr_en),
  .wr_data(tx_data),
  .rd_data(tx_fifo_rd_data),
  .empty(tx_fifo_empty),
  .full(tx_full)
);

endmodule

