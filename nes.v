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
  input  wire       CLK_50MHZ,         // 50MHz system clock signal
  input  wire       BTN_SOUTH,         // reset push button
  input  wire       BTN_EAST,          // console reset
  input  wire       RS232_DCE_RXD,     // rs-232 rx signal
  input  wire       SW0,               // switch 0
  input  wire       NES_JOYPAD_DATA1,  // joypad 1 input signal
  input  wire       NES_JOYPAD_DATA2,  // joypad 2 input signal
  output wire       RS232_DCE_TXD,     // rs-232 tx signal
  output wire       VGA_HSYNC,         // vga hsync signal
  output wire       VGA_VSYNC,         // vga vsync signal
  output wire [3:0] VGA_RED,           // vga red signal
  output wire [3:0] VGA_GREEN,         // vga green signal
  output wire [3:0] VGA_BLUE,          // vga blue signal
  output wire       NES_JOYPAD_CLK,    // joypad output clk signal
  output wire       NES_JOYPAD_LATCH   // joypad output latch signal
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
wire        cpu_nnmi;        // Non-Maskable Interrupt signal (active low)

cpu cpu_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .ready(cpu_ready),
  .dbgreg_sel(cpu_dbgreg_sel),
  .dbgreg_in(cpu_dbgreg_in),
  .dbgreg_wr(cpu_dbgreg_wr),
  .din(cpu_din),
  .nnmi(cpu_nnmi),
  .nres(~BTN_EAST),
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

cpumc cpumc_blk(
  .clk(CLK_50MHZ),
  .wr(~cpumc_r_nw),
  .addr(cpumc_a),
  .din(cpumc_din),
  .dout(cpumc_dout)
);

//
// PPU: picture processing unit block
//
wire [ 2:0] ppu_ri_sel;     // ppu register interface reg select
wire        ppu_ri_ncs;     // ppu register interface enable
wire        ppu_ri_r_nw;    // ppu register interface read/write select
wire [ 7:0] ppu_ri_din;     // ppu register interface data input
wire [ 7:0] ppu_ri_dout;    // ppu register interface data output

wire [13:0] ppu_vram_a;     // ppu video ram address bus
wire        ppu_vram_wr;    // ppu video ram read/write select
wire [ 7:0] ppu_vram_din;   // ppu video ram data bus (input)
wire [ 7:0] ppu_vram_dout;  // ppu video ram data bus (output)

wire        ppu_nvbl;       // ppu /VBL signal.

// PPU snoops the CPU address bus for register reads/writes.  Addresses 0x2000-0x2007
// are mapped to the PPU register space, with every 8 bytes mirrored through 0x3FFF.
assign ppu_ri_sel  = cpumc_a[2:0];
assign ppu_ri_ncs  = (cpumc_a[15:13] == 3'b001) ? 1'b0 : 1'b1;
assign ppu_ri_r_nw = cpumc_r_nw;
assign ppu_ri_din  = cpumc_din;

ppu ppu_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .dbl(SW0),
  .ri_sel(ppu_ri_sel),
  .ri_ncs(ppu_ri_ncs),
  .ri_r_nw(ppu_ri_r_nw),
  .ri_din(ppu_ri_din),
  .vram_din(ppu_vram_din),
  .hsync(VGA_HSYNC),
  .vsync(VGA_VSYNC),
  .r(VGA_RED),
  .g(VGA_GREEN),
  .b(VGA_BLUE),
  .ri_dout(ppu_ri_dout),
  .vram_a(ppu_vram_a),
  .vram_dout(ppu_vram_dout),
  .vram_wr(ppu_vram_wr),
  .nvbl(ppu_nvbl)
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
// JP: joypad controller block
//
wire [ 7:0] jp_din;
wire [ 7:0] jp_dout;
wire [15:0] jp_a;
wire        jp_wr;

jp jp_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .wr(jp_wr),
  .addr(jp_a),
  .din(jp_din),
  .jp_data1(NES_JOYPAD_DATA1),
  .jp_data2(NES_JOYPAD_DATA2),
  .jp_clk(NES_JOYPAD_CLK),
  .jp_latch(NES_JOYPAD_LATCH),
  .dout(jp_dout)
);

//
// DBG: debug block.  Interacts with debugger through serial connection.
//
wire [ 7:0] dbg_cpu_din;        // CPU: D[ 7:0] (data bus [input])
wire [ 7:0] dbg_cpu_dout;       // CPU: D[ 7:0] (data bus [output])
wire [15:0] dbg_cpu_a;          // CPU: A[15:0] (address bus)
wire        dbg_cpu_r_nw;       // CPU: R/!W
wire [ 7:0] dbg_ppu_vram_din;   // PPU: D[ 7:0] (data bus [input])
wire [ 7:0] dbg_ppu_vram_dout;  // PPU: D[ 7:0] (data bus [output])
wire [15:0] dbg_ppu_vram_a;     // PPU: A[15:0] (address bus)
wire        dbg_ppu_vram_wr;    // PPU: WR

dbg dbg_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .rx(RS232_DCE_RXD),
  .brk(cpu_brk),
  .cpu_din(dbg_cpu_din),
  .cpu_dbgreg_in(cpu_dbgreg_out),
  .ppu_vram_din(dbg_ppu_vram_din),
  .tx(RS232_DCE_TXD),
  .cpu_r_nw(dbg_cpu_r_nw),
  .cpu_a(dbg_cpu_a),
  .cpu_dout(dbg_cpu_dout),
  .cpu_ready(cpu_ready),
  .cpu_dbgreg_sel(cpu_dbgreg_sel),
  .cpu_dbgreg_out(cpu_dbgreg_in),
  .cpu_dbgreg_wr(cpu_dbgreg_wr),
  .ppu_vram_wr(dbg_ppu_vram_wr),
  .ppu_vram_a(dbg_ppu_vram_a),
  .ppu_vram_dout(dbg_ppu_vram_dout)
);

// Mux cpumc signals from cpu or dbg blk, depending on debug break state (cpu_ready).
assign cpumc_a     = (cpu_ready) ? cpu_a    : dbg_cpu_a;
assign cpumc_r_nw  = (cpu_ready) ? cpu_r_nw : dbg_cpu_r_nw;
assign cpumc_din   = (cpu_ready) ? cpu_dout : dbg_cpu_dout;

// Mux jp signals from cpu or dbg blk, depending on debug break state (cpu_ready).
assign jp_a   = (cpu_ready) ? cpu_a     : dbg_cpu_a;
assign jp_wr  = (cpu_ready) ? ~cpu_r_nw : ~dbg_cpu_r_nw;
assign jp_din = (cpu_ready) ? cpu_dout  : dbg_cpu_dout;

// CPUMC, PPU, and JP return 0 for reads that don't hit an appropriate region of memory.  The final
// D bus value can be derived by ORing together the output of all blocks that can service a
// memory read.
assign cpu_din     = cpumc_dout | ppu_ri_dout | jp_dout;
assign dbg_cpu_din = cpumc_dout | ppu_ri_dout | jp_dout;

// Mux ppumc signals from ppu or dbg blk, depending on debug break state (cpu_ready).
assign ppumc_a          = (cpu_ready) ? ppu_vram_a    : dbg_ppu_vram_a[13:0];
assign ppumc_wr         = (cpu_ready) ? ppu_vram_wr   : dbg_ppu_vram_wr;
assign ppumc_din        = (cpu_ready) ? ppu_vram_dout : dbg_ppu_vram_dout;
assign ppu_vram_din     = ppumc_dout;
assign dbg_ppu_vram_din = ppumc_dout;

// Issue NMI interupt on PPU vertical blank.
assign cpu_nnmi = ppu_nvbl;

endmodule

