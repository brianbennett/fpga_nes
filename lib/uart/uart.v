///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: uart
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 07/01/2010
//
// Description:
// 
// UART controller.  Universal Asynchronous Receiver/Transmitter control module for an RS-232
// (serial) port.  Designed for a Spartan 3E FPGA.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

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

