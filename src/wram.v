///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: wram
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 03/17/2012
//
// Description:
//
// Work RAM module for an fpga-based NES emulator.  Implements 2KB of on-board CPU RAM as fpga
// block RAM.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module wram
(
  input  wire         clk_in,   // system clock
  input  wire         en_in,    // chip enable
  input  wire         r_nw_in,  // read/write select (read: 0, write: 1)
  input  wire  [10:0] a_in,     // memory address
  input  wire  [ 7:0] d_in,     // data input
  output wire  [ 7:0] d_out     // data output
);

wire       wram_bram_we;
wire [7:0] wram_bram_dout;

single_port_ram_sync #(.ADDR_WIDTH(11),
                       .DATA_WIDTH(8)) wram_bram(
  .clk(clk_in),
  .we(wram_bram_we),
  .addr_a(a_in),
  .din_a(d_in),
  .dout_a(wram_bram_dout)
);

assign wram_bram_we = (en_in) ? ~r_nw_in       : 1'b0;
assign d_out        = (en_in) ? wram_bram_dout : 8'h00;

endmodule

