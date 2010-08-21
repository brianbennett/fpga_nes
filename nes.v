///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: nes
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 08/09/2010
//
// Description:
// 
// Top level module for fpga-based Nintendo Entertainment System emulator.  Designed for a Spartan
// 3E FPGA.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module nes
(
  input  wire CLK_50MHZ,      // 50MHz system clock signal
  input  wire BTN_SOUTH,      // reset push button
  input  wire RS232_DCE_RXD,  // rs-232 rx signal
  output wire RS232_DCE_TXD   // rs-232 tx signal
);

// dbg block: interacts with debugger through serial connection.
dbg dbg_blk(CLK_50MHZ, BTN_SOUTH, RS232_DCE_RXD, RS232_DCE_TXD);

endmodule

