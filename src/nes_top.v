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
  // Board Clock
  input  wire        CLK_50MHZ,         // 50MHz system clock signal

  // Board-Level General Purpose I/O
  input  wire        BTN_SOUTH,         // reset push button
  input  wire        BTN_EAST,          // console reset
  input  wire        SW0,               // switch 0
  
  // RS-232 Serial Port
  input  wire        RS232_DCE_RXD,     // rs-232 rx signal
  output wire        RS232_DCE_TXD,     // rs-232 tx signal

  // NES Joypad Controller
  input  wire        NES_JOYPAD_DATA1,  // joypad 1 input signal
  input  wire        NES_JOYPAD_DATA2,  // joypad 2 input signal
  output wire        NES_JOYPAD_CLK,    // joypad output clk signal
  output wire        NES_JOYPAD_LATCH,  // joypad output latch signal

  // VGA
  output wire        VGA_HSYNC,         // vga hsync signal
  output wire        VGA_VSYNC,         // vga vsync signal
  output wire [ 3:0] VGA_RED,           // vga red signal
  output wire [ 3:0] VGA_GREEN,         // vga green signal
  output wire [ 3:0] VGA_BLUE,          // vga blue signal

  // StrataFlash Parallel NOR Flash RAM
  inout  wire [ 7:0] SF_D,              // tristate data bus
  output wire [23:0] SF_A,              // addr bus (16 MB)
  output wire        SF_BYTE,           // address config (0: 8-bit word, 1: 16-bit word)
  output wire        SF_CE0,            // chip enable
  output wire        SF_OE,             // output enable
  output wire        SF_WE,             // write enable

  // Various devices conflicting with Flash RAM pins, to be explicitly disabled.
  output wire        LCD_E,             // on-board lcd screen enable
  output wire        LCD_RW,            // on-board lcd screen r/w control
  output wire        FPGA_INIT_B,       // fpga config mode, init_b pin
  output wire        SPI_SS_B,          // spi serial flash
  output wire        AD_CONV,           // analog-to-digital converter
  output wire        DAC_CS             // digital-to-analog converter
);

//
// CPU: central processing unit block.
//
wire [ 7:0] cpu_din;         // D[ 7:0] (data bus [input]), split to prevent internal tristates
wire [ 7:0] cpu_dout;        // D[ 7:0] (data bus [output])
wire [15:0] cpu_a;           // A[15:0] (address bus)
wire        cpu_r_nw;        // R/!W
wire        cpu_req;
reg         cpu_ready;       // READY
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
  .req(cpu_req),
  .brk(cpu_brk),
  .dbgreg_out(cpu_dbgreg_out)
);

//
// CPUMC: cpu memory controller block.
//
reg  [ 7:0] cpumc_din;   // D[ 7:0] (data bus [input])
wire [ 7:0] cpumc_dout;  // D[ 7:0] (data bus [output])
reg  [15:0] cpumc_a;     // A[15:0] (address bus)
reg         cpumc_req;   // memory request initiator
reg         cpumc_r_nw;  // R/!W
reg         cpumc_erase; // request erase operation
wire        cpumc_rdy;   // indicates cpumc is ready for a request
wire [ 7:0] cpumc_cfg;   // defines mapper configuration

cpumc cpumc_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .cfg(cpumc_cfg),
  .req(cpumc_req),
  .wr(~cpumc_r_nw),
  .erase(cpumc_erase),
  .addr(cpumc_a),
  .din(cpumc_din),
  .dout(cpumc_dout),
  .sf_rdy(cpumc_rdy),
  .sf_d(SF_D),
  .sf_a(SF_A),
  .sf_byte(SF_BYTE),
  .sf_ce0(SF_CE0),
  .sf_oe(SF_OE),
  .sf_we(SF_WE)
);

//
// PPU: picture processing unit block.
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
  .clk_in(CLK_50MHZ),
  .rst_in(BTN_SOUTH),
  .dbl_in(SW0),
  .ri_sel_in(ppu_ri_sel),
  .ri_ncs_in(ppu_ri_ncs),
  .ri_r_nw_in(ppu_ri_r_nw),
  .ri_d_in(ppu_ri_din),
  .vram_d_in(ppu_vram_din),
  .hsync_out(VGA_HSYNC),
  .vsync_out(VGA_VSYNC),
  .r_out(VGA_RED),
  .g_out(VGA_GREEN),
  .b_out(VGA_BLUE),
  .ri_d_out(ppu_ri_dout),
  .nvbl_out(ppu_nvbl),
  .vram_a_out(ppu_vram_a),
  .vram_d_out(ppu_vram_dout),
  .vram_wr_out(ppu_vram_wr)
);

//
// PPUMC: ppu memory controller block.
//
wire [ 7:0] ppumc_din;         // D[ 7:0] (data bus [input])
wire [ 7:0] ppumc_dout;        // D[ 7:0] (data bus [output])
wire [13:0] ppumc_a;           // A[13:0] (address bus)
wire        ppumc_wr;          // WR
wire [ 7:0] ppumc_mirror_cfg;  // select horizontal/vertical mirroring

ppumc ppumc_blk(
  .clk(CLK_50MHZ),
  .wr(ppumc_wr),
  .addr(ppumc_a),
  .din(ppumc_din),
  .mirror_cfg(ppumc_mirror_cfg),
  .dout(ppumc_dout)
);

//
// JP: joypad controller block.
//
wire        jp_din;
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
// SPRDMA: sprite dma controller block.
//
wire        sprdma_active;
wire [15:0] sprdma_a;
wire [ 7:0] sprdma_dout;
wire        sprdma_r_nw;
wire        sprdma_req;

sprdma sprdma_blk(
  .clk_in(CLK_50MHZ),
  .rst_in(BTN_SOUTH),
  .cpumc_a_in(cpumc_a),
  .cpumc_din_in(cpumc_din),
  .cpumc_dout_in(cpumc_dout),
  .cpu_r_nw_in(cpumc_r_nw),
  .cpumc_rdy_in(cpumc_rdy),
  .active_out(sprdma_active),
  .cpumc_a_out(sprdma_a),
  .cpumc_d_out(sprdma_dout),
  .cpumc_r_nw_out(sprdma_r_nw),
  .cpumc_req(sprdma_req)
);

//
// DBG: debug block.  Interacts with debugger through serial connection.
//
wire        dbg_active;
wire [ 7:0] dbg_cpu_din;        // CPU: D[ 7:0] (data bus [input])
wire [ 7:0] dbg_cpu_dout;       // CPU: D[ 7:0] (data bus [output])
wire [15:0] dbg_cpu_a;          // CPU: A[15:0] (address bus)
wire        dbg_cpu_req;        // CPU: valid memory request
wire        dbg_cpu_r_nw;       // CPU: R/!W
wire        dbg_cpumc_erase;    // CPU: erase request
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
  .cpumc_rdy(cpumc_rdy),
  .tx(RS232_DCE_TXD),
  .active(dbg_active),
  .cpu_req(dbg_cpu_req),
  .cpu_r_nw(dbg_cpu_r_nw),
  .cpumc_erase(dbg_cpumc_erase),
  .cpu_a(dbg_cpu_a),
  .cpu_dout(dbg_cpu_dout),
  .cpu_dbgreg_sel(cpu_dbgreg_sel),
  .cpu_dbgreg_out(cpu_dbgreg_in),
  .cpu_dbgreg_wr(cpu_dbgreg_wr),
  .ppu_vram_wr(dbg_ppu_vram_wr),
  .ppu_vram_a(dbg_ppu_vram_a),
  .ppu_vram_dout(dbg_ppu_vram_dout),
  .ppumc_mirror_cfg(ppumc_mirror_cfg),
  .cpumc_cfg(cpumc_cfg)
);

always @*
  begin
    if (dbg_active)
      begin
        cpu_ready   = 1'b0;
        cpumc_a     = dbg_cpu_a;
        cpumc_r_nw  = dbg_cpu_r_nw;
        cpumc_req   = dbg_cpu_req;
        cpumc_erase = dbg_cpumc_erase;
        cpumc_din   = dbg_cpu_dout;
      end
    else if (sprdma_active)
      begin
        cpu_ready   = 1'b0;
        cpumc_a     = sprdma_a;
        cpumc_r_nw  = sprdma_r_nw;
        cpumc_req   = sprdma_req;
        cpumc_erase = 1'b0;
        cpumc_din   = sprdma_dout;
      end
    else
      begin
        cpu_ready   = 1'b1;
        cpumc_a     = cpu_a;
        cpumc_r_nw  = cpu_r_nw;
        cpumc_req   = cpu_req;
        cpumc_erase = 1'b0;
        cpumc_din   = cpu_dout;
      end
  end

// Mux jp signals from cpu or dbg blk, depending on debug break state (dbg_active).
assign jp_a   = (dbg_active) ? dbg_cpu_a       : cpu_a;
assign jp_wr  = (dbg_active) ? ~dbg_cpu_r_nw   : ~cpu_r_nw;
assign jp_din = (dbg_active) ? dbg_cpu_dout[0] : cpu_dout[0];

// CPUMC, PPU, and JP return 0 for reads that don't hit an appropriate region of memory.  The final
// D bus value can be derived by ORing together the output of all blocks that can service a
// memory read.
assign cpu_din     = cpumc_dout | ppu_ri_dout | jp_dout;
assign dbg_cpu_din = cpumc_dout | ppu_ri_dout | jp_dout;

// Mux ppumc signals from ppu or dbg blk, depending on debug break state (dbg_active).
assign ppumc_a          = (dbg_active) ? dbg_ppu_vram_a[13:0] : ppu_vram_a;
assign ppumc_wr         = (dbg_active) ? dbg_ppu_vram_wr      : ppu_vram_wr;
assign ppumc_din        = (dbg_active) ? dbg_ppu_vram_dout    : ppu_vram_dout;
assign ppu_vram_din     = ppumc_dout;
assign dbg_ppu_vram_din = ppumc_dout;

// Issue NMI interupt on PPU vertical blank.
assign cpu_nnmi = ppu_nvbl;

// Disable conflicting devices
assign LCD_E       = 1'b0;
assign LCD_RW      = 1'b0;
assign FPGA_INIT_B = 1'b0;
assign SPI_SS_B    = 1'b1;
assign AD_CONV     = 1'b0;
assign DAC_CS      = 1'b1;

endmodule

