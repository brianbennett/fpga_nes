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
  input  wire       CLK_50MHZ,      // 50MHz system clock signal
  input  wire       BTN_SOUTH,      // reset push button
  input  wire       RS232_DCE_RXD,  // rs-232 rx signal
  input  wire       SW0,            // switch 0
  output wire       RS232_DCE_TXD,  // rs-232 tx signal
  output wire       VGA_HSYNC,      // vga hsync signal
  output wire       VGA_VSYNC,      // vga vsync signal
  output wire [3:0] VGA_RED,        // vga red signal
  output wire [3:0] VGA_GREEN,      // vga green signal
  output wire [3:0] VGA_BLUE        // vga blue signal
);

//
// CPU: central processing unit block.
//
wire [ 7:0] cpu_din;         // D[ 7:0] (data bus [input]), split to prevent internal tristates
wire [ 7:0] cpu_dout;        // D[ 7:0] (data bus [output])
wire [15:0] cpu_a;           // A[15:0] (address bus)
wire        cpu_r_nw;        // R/!W
wire        cpu_ready;       // READY
wire        cpu_brk;         // signals CPU-intiated debug break
wire [ 3:0] cpu_dbgreg_sel;  // CPU input for debugger register read/write select
wire [ 7:0] cpu_dbgreg_out;  // CPU output for debugger register reads
wire [ 7:0] cpu_dbgreg_in;   // CPU input for debugger register writes
wire        cpu_dbgreg_wr;   // CPU input for debugger register writen enable

cpu cpu_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .ready(cpu_ready),
  .dbgreg_sel(cpu_dbgreg_sel),
  .dbgreg_in(cpu_dbgreg_in),
  .dbgreg_wr(cpu_dbgreg_wr),
  .din(cpu_din),
  .dout(cpu_dout),
  .a(cpu_a),
  .r_nw(cpu_r_nw),
  .brk(cpu_brk),
  .dbgreg_out(cpu_dbgreg_out)
);

//
// CPUMC: cpu memory controller block.
//
wire [ 7:0] cpumc_din;   // D[ 7:0] (data bus [input])
wire [ 7:0] cpumc_dout;  // D[ 7:0] (data bus [output])
wire [15:0] cpumc_a;     // A[15:0] (address bus)
wire        cpumc_r_nw;  // R/!W
wire        cpumc_err;   // Error signal for cpumc block

cpumc cpumc_blk(
  .clk(CLK_50MHZ),
  .wr(~cpumc_r_nw),
  .addr(cpumc_a),
  .din(cpumc_din),
  .dout(cpumc_dout),
  .invalid_req(cpumc_err)
);

//
// PPU: picture processing unit block
//
ppu ppu_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .dbl(SW0),
  .hsync(VGA_HSYNC),
  .vsync(VGA_VSYNC),
  .r(VGA_RED),
  .g(VGA_GREEN),
  .b(VGA_BLUE)
);

//
// PPUMC: ppu memory controller block.
//
wire [ 7:0] ppumc_din;   // D[ 7:0] (data bus [input])
wire [ 7:0] ppumc_dout;  // D[ 7:0] (data bus [output])
wire [13:0] ppumc_a;     // A[13:0] (address bus)
wire        ppumc_wr;    // WR

ppumc ppumc_blk(
  .clk(CLK_50MHZ),
  .wr(ppumc_wr),
  .addr(ppumc_a),
  .din(ppumc_din),
  .dout(ppumc_dout)
);

//
// DBG: debug block.  Interacts with debugger through serial connection.
//
wire [ 7:0] dbg_cpu_din;   // CPU: D[ 7:0] (data bus [input])
wire [ 7:0] dbg_cpu_dout;  // CPU: D[ 7:0] (data bus [output])
wire [15:0] dbg_cpu_a;     // CPU: A[15:0] (address bus)
wire        dbg_cpu_r_nw;  // CPU: R/!W
wire [ 7:0] dbg_ppu_din;   // PPU: D[ 7:0] (data bus [input])
wire [ 7:0] dbg_ppu_dout;  // PPU: D[ 7:0] (data bus [output])
wire [15:0] dbg_ppu_a;     // PPU: A[15:0] (address bus)
wire        dbg_ppu_wr;    // PPU: WR

dbg dbg_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .rx(RS232_DCE_RXD),
  .cpumc_err(cpumc_err),
  .brk(cpu_brk),
  .cpu_din(dbg_cpu_din),
  .cpu_dbgreg_in(cpu_dbgreg_out),
  .ppu_din(dbg_ppu_din),
  .tx(RS232_DCE_TXD),
  .cpu_r_nw(dbg_cpu_r_nw),
  .cpu_a(dbg_cpu_a),
  .cpu_dout(dbg_cpu_dout),
  .cpu_ready(cpu_ready),
  .cpu_dbgreg_sel(cpu_dbgreg_sel),
  .cpu_dbgreg_out(cpu_dbgreg_in),
  .cpu_dbgreg_wr(cpu_dbgreg_wr),
  .ppu_wr(dbg_ppu_wr),
  .ppu_a(dbg_ppu_a),
  .ppu_dout(dbg_ppu_dout)
);

// Mux cpumc signals from cpu or dbg blk, depending on debug break state (cpu_ready).
assign cpumc_a     = (cpu_ready) ? cpu_a    : dbg_cpu_a;
assign cpumc_r_nw  = (cpu_ready) ? cpu_r_nw : dbg_cpu_r_nw;
assign cpumc_din   = (cpu_ready) ? cpu_dout : dbg_cpu_dout;
assign cpu_din     = cpumc_dout;
assign dbg_cpu_din = cpumc_dout;

// Mux ppumc signals from ppu or dbg blk, depending on debug break state (cpu_ready).
assign ppumc_a     = dbg_ppu_a[13:0];
assign ppumc_wr    = dbg_ppu_wr;
assign ppumc_din   = dbg_ppu_dout;
assign dbg_ppu_din = ppumc_dout;

endmodule

