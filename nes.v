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

wire [ 7:0] cpu_d;     // D[ 7:0] (data bus)
wire [15:0] cpu_a;     // A[15:0] (address bus)
wire        cpu_r_nw;  // R/!W

wire        cpumc_err; // Error signal for cpumc block

// cpumc block: cpu memory controller.
cpumc cpumc_blk(
  .clk(CLK_50MHZ),
  .wr(~cpu_r_nw),
  .addr(cpu_a),
  .data(cpu_d),
  .invalid_req(cpumc_err)
);

// dbg block: interacts with debugger through serial connection.
dbg dbg_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .rx(RS232_DCE_RXD),
  .cpumc_err(cpumc_err),
  .cpu_d(cpu_d),
  .tx(RS232_DCE_TXD),
  .cpu_r_nw(cpu_r_nw),
  .cpu_a(cpu_a)
);

endmodule

