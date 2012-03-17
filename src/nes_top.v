///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: nes_top
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
// System Busses
//
reg  [ 7:0] cpumc_din;
reg  [15:0] cpumc_a;
reg         cpumc_r_nw;

wire [ 7:0] ppumc_din;
wire [13:0] ppumc_a;
wire        ppumc_wr;
wire [ 7:0] ppumc_mirror_cfg;

//
// CPU: central processing unit block.
//
wire [ 7:0] cpu_din;         // D[ 7:0] (data bus [input]), split to prevent internal tristates
wire [ 7:0] cpu_dout;        // D[ 7:0] (data bus [output])
wire [15:0] cpu_a;           // A[15:0] (address bus)
wire        cpu_r_nw;        // R/!W
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
  .brk(cpu_brk),
  .dbgreg_out(cpu_dbgreg_out)
);

//
// CART: cartridge emulator
//
wire       cart_prg_nce;
wire [7:0] cart_prg_dout;
wire [7:0] cart_chr_dout;
wire       cart_ciram_nce;
wire       cart_ciram_a10;

cart cart_blk(
  .clk_in(CLK_50MHZ),
  .mirror_cfg_in(ppumc_mirror_cfg[0]),
  .prg_nce_in(cart_prg_nce),
  .prg_a_in(cpumc_a[14:0]),
  .prg_r_nw_in(cpumc_r_nw),
  .prg_d_in(cpumc_din),
  .prg_d_out(cart_prg_dout),
  .chr_a_in(ppumc_a),
  .chr_r_nw_in(~ppumc_wr),
  .chr_d_in(ppumc_din),
  .chr_d_out(cart_chr_dout),
  .ciram_nce_out(cart_ciram_nce),
  .ciram_a10_out(cart_ciram_a10)
);

assign cart_prg_nce = ~cpumc_a[15];

//
// WRAM: internal work ram
//
wire       wram_en;
wire [7:0] wram_dout;

wram wram_blk(
  .clk_in(CLK_50MHZ),
  .en_in(wram_en),
  .r_nw_in(cpumc_r_nw),
  .a_in(cpumc_a[10:0]),
  .d_in(cpumc_din),
  .d_out(wram_dout)
);

assign wram_en = (cpumc_a[15:13] == 0);

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
// VRAM: internal video ram
//
wire [10:0] vram_a;
wire [ 7:0] vram_dout;

vram vram_blk(
  .clk_in(CLK_50MHZ),
  .en_in(~cart_ciram_nce),
  .r_nw_in(~ppumc_wr),
  .a_in(vram_a),
  .d_in(ppumc_din),
  .d_out(vram_dout)
);

assign vram_a = { cart_ciram_a10, ppumc_a[9:0] };

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

sprdma sprdma_blk(
  .clk_in(CLK_50MHZ),
  .rst_in(BTN_SOUTH),
  .cpumc_a_in(cpumc_a),
  .cpumc_din_in(cpumc_din),
  .cpumc_dout_in(cpu_din),
  .cpu_r_nw_in(cpumc_r_nw),
  .active_out(sprdma_active),
  .cpumc_a_out(sprdma_a),
  .cpumc_d_out(sprdma_dout),
  .cpumc_r_nw_out(sprdma_r_nw)
);

//
// HCI: host communication interface block.  Interacts with NesDbg software through serial port.
//
wire        hci_active;
wire [ 7:0] hci_cpu_din;        // CPU: D[ 7:0] (data bus [input])
wire [ 7:0] hci_cpu_dout;       // CPU: D[ 7:0] (data bus [output])
wire [15:0] hci_cpu_a;          // CPU: A[15:0] (address bus)
wire        hci_cpu_r_nw;       // CPU: R/!W
wire [ 7:0] hci_ppu_vram_din;   // PPU: D[ 7:0] (data bus [input])
wire [ 7:0] hci_ppu_vram_dout;  // PPU: D[ 7:0] (data bus [output])
wire [15:0] hci_ppu_vram_a;     // PPU: A[15:0] (address bus)
wire        hci_ppu_vram_wr;    // PPU: WR

hci hci_blk(
  .clk(CLK_50MHZ),
  .rst(BTN_SOUTH),
  .rx(RS232_DCE_RXD),
  .brk(cpu_brk),
  .cpu_din(hci_cpu_din),
  .cpu_dbgreg_in(cpu_dbgreg_out),
  .ppu_vram_din(hci_ppu_vram_din),
  .tx(RS232_DCE_TXD),
  .active(hci_active),
  .cpu_r_nw(hci_cpu_r_nw),
  .cpu_a(hci_cpu_a),
  .cpu_dout(hci_cpu_dout),
  .cpu_dbgreg_sel(cpu_dbgreg_sel),
  .cpu_dbgreg_out(cpu_dbgreg_in),
  .cpu_dbgreg_wr(cpu_dbgreg_wr),
  .ppu_vram_wr(hci_ppu_vram_wr),
  .ppu_vram_a(hci_ppu_vram_a),
  .ppu_vram_dout(hci_ppu_vram_dout),
  .ppumc_mirror_cfg(ppumc_mirror_cfg)
);

always @*
  begin
    if (hci_active)
      begin
        cpu_ready  = 1'b0;
        cpumc_a    = hci_cpu_a;
        cpumc_r_nw = hci_cpu_r_nw;
        cpumc_din  = hci_cpu_dout;
      end
    else if (sprdma_active)
      begin
        cpu_ready  = 1'b0;
        cpumc_a    = sprdma_a;
        cpumc_r_nw = sprdma_r_nw;
        cpumc_din  = sprdma_dout;
      end
    else
      begin
        cpu_ready  = 1'b1;
        cpumc_a    = cpu_a;
        cpumc_r_nw = cpu_r_nw;
        cpumc_din  = cpu_dout;
      end
  end

// Mux jp signals from cpu or hci blk, depending on debug break state (hci_active).
assign jp_a   = (hci_active) ? hci_cpu_a       : cpu_a;
assign jp_wr  = (hci_active) ? ~hci_cpu_r_nw   : ~cpu_r_nw;
assign jp_din = (hci_active) ? hci_cpu_dout[0] : cpu_dout[0];

// CART, WRAM, PPU, and JP return 0 for reads that don't hit an appropriate region of memory.  The
// final CPU D bus value can be derived by ORing together the output of all blocks that can service
// a memory read.
assign cpu_din     = cart_prg_dout | wram_dout | ppu_ri_dout | jp_dout;
assign hci_cpu_din = cart_prg_dout | wram_dout | ppu_ri_dout | jp_dout;

// Mux ppumc signals from ppu or hci blk, depending on debug break state (hci_active).
assign ppumc_a          = (hci_active) ? hci_ppu_vram_a[13:0] : ppu_vram_a;
assign ppumc_wr         = (hci_active) ? hci_ppu_vram_wr      : ppu_vram_wr;
assign ppumc_din        = (hci_active) ? hci_ppu_vram_dout    : ppu_vram_dout;
assign ppu_vram_din     = cart_chr_dout | vram_dout;
assign hci_ppu_vram_din = cart_chr_dout | vram_dout;

// Issue NMI interupt on PPU vertical blank.
assign cpu_nnmi = ppu_nvbl;

endmodule

