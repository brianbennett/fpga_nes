///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: ppu
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 02/06/2011
//
// Description:
//
// Picture processing unit block for an fpga-based NES emulator.  Designed for a Spartan 3E FPGA.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module ppu
(
  input  wire        clk,        // 50MHz system clock signal
  input  wire        rst,        // reset signal
  input  wire        dbl,        // request nes resolution doubler
  input  wire [ 2:0] ri_sel,     // register interface reg select
  input  wire        ri_ncs,     // register interface enable
  input  wire        ri_r_nw,    // register interface read/write select
  input  wire [ 7:0] ri_din,     // register interface data in
  input  wire [ 7:0] vram_din,   // video memory data bus (input)
  output wire        hsync,      // vga hsync signal
  output wire        vsync,      // vga vsync signal
  output wire [ 3:0] r,          // vga red signal
  output wire [ 3:0] g,          // vga green signal
  output wire [ 3:0] b,          // vga blue signal
  output wire [ 7:0] ri_dout,    // register interface data out
  output wire [13:0] vram_a,     // video memory address bus
  output wire [ 7:0] vram_dout,  // video memory data bus (output)
  output reg         vram_wr,    // video memory read/write select
  output wire        nvbl        // /VBL (low during vertical blank)
);

// Display dimensions (640x480).
localparam [ 9:0] DISPLAY_W          = 10'h280,
                  DISPLAY_H          = 10'h1E0;

// NES screen dimensions (256x240).
localparam [ 9:0] NES_W              = 10'h100,
                  NES_H              = 10'h0F0;

// Border color (surrounding NES screen).
localparam [11:0] BORDER_COLOR       = 12'h888;

// PPU memory segment base addresses.
localparam [13:0] PATTERN_TABLE      = 14'h0000;
localparam [13:0] NAME_TABLE         = 14'h2000;
localparam [13:0] ATTRIBUTE_TABLE    = 14'h23C0;
localparam [13:0] IMAGE_PALETTE      = 14'h3F00;
localparam [13:0] SPRITE_PALETTE     = 14'h3F10;

// Register interface buffered memory command ids.
//    bit[0]: 0 = invalid req, 1 = valid req
//    bit[1]: 0 = read,        1 = write
localparam [ 1:0] RI_MEM_CMD_NOP     = 2'b00,
                  RI_MEM_CMD_RD      = 2'b01,
                  RI_MEM_CMD_WR      = 2'b11;

// VRAM bus owner select values.
localparam        SEL_VRAM_A_DISPLAY = 1'b0,
                  SEL_VRAM_A_RI      = 1'b1;

//
// PPU registers.
//
reg [11:0] q_rgb,            d_rgb;             // output color latch (required by vga_sync)

// Background fetch registers.
reg [ 7:0] q_tile_name,      d_tile_name;       // name for next tile (index for pattern bytes)
reg [15:0] q_attribute,      d_attribute;       // attribute bytes (next 2 tiles, shifted reg)
reg [15:0] q_tile_bit0,      d_tile_bit0;       // pattern bit0 byte (next 2 tiles, shifted reg)
reg [15:0] q_tile_bit1,      d_tile_bit1;       // pattern bit1 byte (next 2 tiles, shifted reg)

// Register interface (RI) registers.
reg [13:0] q_ri_addr,        d_ri_addr;         // ri: addr (updated by writing 0x2006)
reg        q_ri_byte_sel,    d_ri_byte_sel;     // ri: tracks if next ri write is high or low byte
reg [ 7:0] q_ri_dout,        d_ri_dout;         // ri: output data bus latch (for 0x2007 reads)
reg [13:0] q_ri_addr_buf,    d_ri_addr_buf;     // ri: addr buffer (for buffered mem reads/writes)
reg [ 7:0] q_ri_rd_data_buf, d_ri_rd_data_buf;  // ri: read data buffer (buffered mem read src)
reg [ 7:0] q_ri_wr_data_buf, d_ri_wr_data_buf;  // ri: write data buffer (buffered mem write dst)
reg [ 1:0] q_ri_mem_cmd,     d_ri_mem_cmd;      // ri: buffered memory command
reg        q_ri_mem_rd_rdy,  d_ri_mem_rd_rdy;   // ri: mem command complete signal
reg        q_ri_ncs;                            // ri: last ncs signal (to detect ncs edges)

//
// PPU Control Register 0
//
// Bits  Desc
// 0-1   Name table address, changes between the four name tables at 0x2000 (0), 0x2400 (1), 
//       0x2800 (2), 0x2C000 (3).
// 2     Specifies amount to increment address by, either 1 if this is 0 or 32 if this is 1.
// 3     Identifies which pattern table sprites are stored in, either $0000 (0) or $1000 (1).
// 4     Identifies which pattern table the background is stored in, either $0000 (0) or $1000 (1).
// 5     Specifies the size of sprites in pixels, 8x8 if this is 0, otherwise 8x16.
// 6     Changes PPU between master and slave modes. This is not used by the NES.
// 7     Indicates whether a NMI should occur upon V-Blank.
//       
reg [7:0] q_ppu_cntl_0, d_ppu_cntl_0;

`define NAME_TABLE_ADDR  (q_ppu_cntl_0[1:0])
`define RI_ADDR_INCR     ((q_ppu_cntl_0[2]) ? 6'h20 : 6'h01)
`define PATTERN_TBL_ADDR (q_ppu_cntl_0[4])
`define NVBL_EN          (q_ppu_cntl_0[7])

//
// PPU Control Register 1
// 
// Bits  Desc
// 0     Indicates whether the system is in color (0) or monochrome mode (1).
// 1     Specifies whether to clip the background, that is whether to hide the background in the
//       left 8 pixels on screen (0) or to show them (1).
// 2     Specifies whether to clip the sprites, that is whether to hide sprites in the left 8
//       pixels on screen (0) or to show them (1).
// 3     If this is 0, the background should not be displayed.
// 4     If this is 0, sprites should not be displayed.
// 5-7   Indicates background colour in monochrome mode or colour intensity in colour mode.
//
reg [7:0] q_ppu_cntl_1, d_ppu_cntl_1;

`define BG_EN (q_ppu_cntl_1[3])

//
// PPU Status Register
// 
// Bits  Desc
// 4     If set, indicates that writes to VRAM should be ignored.
// 5     Scanline sprite count, if set, indicates more than 8 sprites on the current scanline.
// 6     Sprite 0 hit flag, set when a non-transparent pixel of sprite 0 overlaps a
//       non-transparent background pixel.
// 7     Indicates whether V-Blank is occurring.
// 
reg [7:0] q_ppu_status, d_ppu_status;

`define D_VBLANK_STATUS d_ppu_status[7]
`define Q_VBLANK_STATUS q_ppu_status[7]

//
// PPU internal RAM and control.
//
reg  [5:0] palette_ram [31:0];

wire [5:0] palette_ram_din;  // vram_din equivalent for palette_ram reads
reg        wr_palette_ram;   // enable palette ram write

//
// Control signals.
//
reg         sel_vram_a;      // selects vram address bus driver (0 = display, 1 = ri)
reg  [13:0] display_a;       // display address request
reg  [13:0] ri_a;            // register interface address request

//
// Display timing and coord control.
//
wire       vga_en;           // vga enable signal
wire [9:0] vga_x, vga_y;     // vga x and y coordinates
wire [9:0] x, y;             // nes x and y coordinates
wire [4:0] tile_x, tile_y;   // nes x and y tile coordinates
wire [4:0] next_tile_x;      // nes next x tile (tile_x + 1, with wrap)
wire       border;           // indicates we are displaying a vga pixel outside the nes extents
wire       vblank;           // vertical blank, VRAM not being read by display

reg  [4:0] q_tile_x;         // last clock's tile_x, for new tile edge detection
reg        q_vblank;         // last clock's vblank, for vblank edge detection

//
// Image composition signals.
//
wire [3:0] bg_palette_idx;   // final background palette index
wire [5:0] sys_palette_idx;  // final composed system palette index

//
// VGA_SYNC: VGA synchronization control block.
//
vga_sync vga_sync_blk(
  .clk(clk),
  .hsync(hsync),
  .vsync(vsync),
  .en(vga_en),
  .x(vga_x),
  .y(vga_y)
);

//
// Update PPU internal RAM.
//
always @(posedge clk)
  begin
    if (wr_palette_ram)
      palette_ram[q_ri_addr_buf[4:0]] <= q_ri_wr_data_buf;
  end

//
// Update internal PPU registers.
//
always @(posedge clk)
  begin
    if (rst)
      begin
        q_rgb              <= 12'h000;
        q_tile_name        <= 8'h00;
        q_attribute        <= 16'h0000;
        q_tile_bit0        <= 16'h0000;
        q_tile_bit1        <= 16'h0000;
        q_ri_addr          <= 14'h0000;
        q_ri_byte_sel      <= 1'b1;
        q_ri_dout          <= 8'h00;
        q_ri_addr_buf      <= 14'h0200;
        q_ri_rd_data_buf   <= 8'h00;
        q_ri_wr_data_buf   <= 8'h00;
        q_ri_mem_cmd       <= 2'b00;
        q_ri_mem_rd_rdy    <= 1'b0;
        q_ri_ncs           <= 1'b1;
        q_ppu_cntl_0       <= 8'h00;
        q_ppu_cntl_1       <= 8'h00;
        q_ppu_status       <= 8'h00;
        q_tile_x           <= 5'h00;
        q_vblank           <= 1'b0;
      end
    else
      begin
        q_rgb              <= d_rgb;
        q_tile_name        <= d_tile_name;
        q_attribute        <= d_attribute;
        q_tile_bit0        <= d_tile_bit0;
        q_tile_bit1        <= d_tile_bit1;
        q_ri_addr          <= d_ri_addr;
        q_ri_byte_sel      <= d_ri_byte_sel;
        q_ri_dout          <= d_ri_dout;
        q_ri_addr_buf      <= d_ri_addr_buf;
        q_ri_rd_data_buf   <= d_ri_rd_data_buf;
        q_ri_wr_data_buf   <= d_ri_wr_data_buf;
        q_ri_mem_cmd       <= d_ri_mem_cmd;
        q_ri_mem_rd_rdy    <= d_ri_mem_rd_rdy;
        q_ri_ncs           <= ri_ncs;
        q_ppu_cntl_0       <= d_ppu_cntl_0;
        q_ppu_cntl_1       <= d_ppu_cntl_1;
        q_ppu_status       <= d_ppu_status;
        q_tile_x           <= tile_x;
        q_vblank           <= vblank;
      end
  end

//
// External register interface.
//
assign palette_ram_din = palette_ram[q_ri_addr_buf[4:0]];

always @*
  begin
    // Default RI registers to their original values.
    d_ri_addr          = q_ri_addr;
    d_ri_byte_sel      = q_ri_byte_sel;
    d_ri_dout          = q_ri_dout;
    d_ri_addr_buf      = q_ri_addr_buf;
    d_ri_rd_data_buf   = q_ri_rd_data_buf;
    d_ri_wr_data_buf   = q_ri_wr_data_buf;
    d_ri_mem_cmd       = q_ri_mem_cmd;
    d_ppu_cntl_0       = q_ppu_cntl_0;
    d_ppu_cntl_1       = q_ppu_cntl_1;
    d_ppu_status       = q_ppu_status;

    d_ri_mem_rd_rdy    = 1'b0;

    ri_a               = q_ri_addr_buf;
    vram_wr            = 1'b0;
    wr_palette_ram     = 1'b0;

    // Set the vblank status bit on a rising vblank edge.  Clear it if vblank is false.  Can also
    // be cleared by reading 0x2002.
    `D_VBLANK_STATUS = (vblank & ~q_vblank) ? 1'b1 :
                       (~vblank)             ? 1'b0 : `Q_VBLANK_STATUS;

    // Only evaluate RI reads/writes on /CS falling edges.  This prevents executing the same
    // command multiple times because the CPU runs at a slower clock rate than the PPU.
    if (!ri_ncs && q_ri_ncs)
      begin
        if (ri_r_nw)
          begin
            // External register read.
            case (ri_sel)
              3'h2:  // 0x2002
                begin
                  d_ri_dout = q_ppu_status;

                  d_ri_byte_sel    = 1'b1;
                  `D_VBLANK_STATUS = 1'b0;
                end
              3'h7:  // 0x2007
                begin
                  // Setup buffered read command.
                  d_ri_mem_cmd  = RI_MEM_CMD_RD;
                  d_ri_addr_buf = q_ri_addr;

                  // Move previous read result to output, and update addr for next ri op.
                  d_ri_dout = q_ri_rd_data_buf;
                  d_ri_addr = q_ri_addr + `RI_ADDR_INCR;
                end
            endcase
          end
        else
          begin
            // External register write.
            case (ri_sel)
              3'h0:  // 0x2000
                d_ppu_cntl_0 = ri_din;
              3'h1:  // 0x2001
                d_ppu_cntl_1 = ri_din;
              3'h6:  // 0x2006
                begin
                  d_ri_byte_sel = ~q_ri_byte_sel;
                  if (q_ri_byte_sel)
                    d_ri_addr = (ri_din << 8) | (q_ri_addr & 16'h00FF);
                  else
                    d_ri_addr = (q_ri_addr & 16'hFF00) | ri_din;
                end
              3'h7:  // 0x2007
                begin
                  // Setup buffered write command.
                  d_ri_mem_cmd     = RI_MEM_CMD_WR;
                  d_ri_addr_buf    = q_ri_addr;
                  d_ri_wr_data_buf = ri_din;

                  // Update addr for next ri op.
                  d_ri_addr = q_ri_addr + `RI_ADDR_INCR;
                end
            endcase
          end
      end

    if ((sel_vram_a == SEL_VRAM_A_RI) && (q_ri_mem_cmd[0]))
      begin
        d_ri_mem_cmd = RI_MEM_CMD_NOP;

        d_ri_mem_rd_rdy = ~q_ri_mem_cmd[1];

        // Palette RAM writes.
        if (q_ri_addr_buf[13:8] == 6'h3F)
          wr_palette_ram = q_ri_mem_cmd[1];
        // VRAM writes.
        else
          vram_wr = q_ri_mem_cmd[1];
      end

    if (q_ri_mem_rd_rdy)
      begin
        // Palette RAM reads.
        if (q_ri_addr_buf[13:8] == 6'h3F)
          d_ri_rd_data_buf = { 2'b00, palette_ram_din };
        // VRAM reads.
        else
          d_ri_rd_data_buf = vram_din;
      end
  end

//
// Translate <vga_x, vga_y> to NES display coordinates.  Account for resolution doubling
// if necessary.
//
assign x           = (vga_x - ((DISPLAY_W - (NES_W << dbl)) >> 1)) >> dbl;
assign y           = (vga_y - ((DISPLAY_H - (NES_H << dbl)) >> 1)) >> dbl;
assign tile_x      = x >> 3;
assign tile_y      = y >> 3;
assign next_tile_x = tile_x + 5'h01;
assign border      = (x >= NES_W) || (y >= NES_H);
assign vblank      = (y >= NES_H);

//
// Derive output color (system palette index).
//
always @*
  begin
    // Default registers to their current values.
    d_tile_name = q_tile_name;
    d_attribute = q_attribute;
    d_tile_bit0 = q_tile_bit0;
    d_tile_bit1 = q_tile_bit1;

    sel_vram_a = SEL_VRAM_A_DISPLAY;
    display_a  = 14'h0000;

    // Shift attribute and pattern bit registers on a new tile.  New tile will be stored in 7:0.
    if (tile_x != q_tile_x)
      begin
        d_attribute = q_attribute << 8;
        d_tile_bit0 = q_tile_bit0 << 8;
        d_tile_bit1 = q_tile_bit1 << 8;
      end

    if (`BG_EN && !vblank)
      case (x[2:0])
        3'b000:
          begin
            // Stage 0.  Load next tile's name.
            display_a = { NAME_TABLE[13:12],
                          `NAME_TABLE_ADDR,
                          tile_y[4:0],
                          next_tile_x[4:0] };
            d_tile_name = vram_din;
          end
        3'b001:
          begin
            // Stage 1.  Load next tile's attrib byte.
            display_a = { ATTRIBUTE_TABLE[13:12],
                          `NAME_TABLE_ADDR,
                          ATTRIBUTE_TABLE[9:6],
                          tile_y[4:2],
                          next_tile_x[4:2] };
            d_attribute[7:0] = vram_din;
          end
        3'b010:
          begin
            // Stage 2.  Load bit0 pattern data based on tile name.
            display_a = { PATTERN_TABLE[13],
                          `PATTERN_TBL_ADDR,
                          q_tile_name,
                          1'b0,
                          y[2:0] };
            d_tile_bit0[7:0] = vram_din;
          end
        3'b011:
          begin
            // Stage 3.  Load bit1 pattern data based on tile name.
            display_a = { PATTERN_TABLE[13],
                          `PATTERN_TBL_ADDR,
                          q_tile_name,
                          1'b1,
                          y[2:0] };
            d_tile_bit1[7:0] = vram_din;
          end
        default:
          begin
            sel_vram_a = SEL_VRAM_A_RI;
          end
      endcase
    else
      sel_vram_a = SEL_VRAM_A_RI;
  end

//
// Image composition.
//
assign bg_palette_idx = { q_attribute[15:8] >> { tile_y[1], tile_x[1], 1'b0 },
                          q_tile_bit1[4'hF - { 1'b0, x[2:0] }],
                          q_tile_bit0[4'hF - { 1'b0, x[2:0] }] };
assign sys_palette_idx = (`BG_EN) ? palette_ram[{1'b0, bg_palette_idx}] : 6'h00;

//
// Lookup RGB values based on sys_palette_idx.
//
always @*
  begin
    if (!vga_en)
      begin
        d_rgb = 12'h000;
      end
    else if (border)
      begin
        d_rgb = BORDER_COLOR;
      end
    else
      begin
        // Lookup RGB values based on sys_palette_idx.  Table is an approximation of the NES
        // system palette.  Taken from http://nesdev.parodius.com/NESTechFAQ.htm#nessnescompat.
        case (sys_palette_idx)
          6'h00:  d_rgb = 12'h888;
          6'h01:  d_rgb = 12'h03a;
          6'h02:  d_rgb = 12'h01b;
          6'h03:  d_rgb = 12'h409;
          6'h04:  d_rgb = 12'ha05;
          6'h05:  d_rgb = 12'hc02;
          6'h06:  d_rgb = 12'hb00;
          6'h07:  d_rgb = 12'h810;
          6'h08:  d_rgb = 12'h520;
          6'h09:  d_rgb = 12'h140;
          6'h0a:  d_rgb = 12'h040;
          6'h0b:  d_rgb = 12'h042;
          6'h0c:  d_rgb = 12'h046;
          6'h0d:  d_rgb = 12'h000;
          6'h0e:  d_rgb = 12'h000;
          6'h0f:  d_rgb = 12'h000;

          6'h10:  d_rgb = 12'hccc;
          6'h11:  d_rgb = 12'h07f;
          6'h12:  d_rgb = 12'h25f;
          6'h13:  d_rgb = 12'h83f;
          6'h14:  d_rgb = 12'he2b;
          6'h15:  d_rgb = 12'hf25;
          6'h16:  d_rgb = 12'hf20;
          6'h17:  d_rgb = 12'hd30;
          6'h18:  d_rgb = 12'hc60;
          6'h19:  d_rgb = 12'h380;
          6'h1a:  d_rgb = 12'h080;
          6'h1b:  d_rgb = 12'h085;
          6'h1c:  d_rgb = 12'h09c;
          6'h1d:  d_rgb = 12'h222;
          6'h1e:  d_rgb = 12'h000;
          6'h1f:  d_rgb = 12'h000;

          6'h20:  d_rgb = 12'hfff;
          6'h21:  d_rgb = 12'h0df;
          6'h22:  d_rgb = 12'h6af;
          6'h23:  d_rgb = 12'hd8f;
          6'h24:  d_rgb = 12'hf4f;
          6'h25:  d_rgb = 12'hf68;
          6'h26:  d_rgb = 12'hf83;
          6'h27:  d_rgb = 12'hf91;
          6'h28:  d_rgb = 12'hfb2;
          6'h29:  d_rgb = 12'h9e0;
          6'h2a:  d_rgb = 12'h2f3;
          6'h2b:  d_rgb = 12'h0fa;
          6'h2c:  d_rgb = 12'h0ff;
          6'h2d:  d_rgb = 12'h555;
          6'h2e:  d_rgb = 12'h000;
          6'h2f:  d_rgb = 12'h000;

          6'h30:  d_rgb = 12'hfff;
          6'h31:  d_rgb = 12'haff;
          6'h32:  d_rgb = 12'hbef;
          6'h33:  d_rgb = 12'hdae;
          6'h34:  d_rgb = 12'hfaf;
          6'h35:  d_rgb = 12'hfab;
          6'h36:  d_rgb = 12'hfdb;
          6'h37:  d_rgb = 12'hfea;
          6'h38:  d_rgb = 12'hff9;
          6'h39:  d_rgb = 12'hde9;
          6'h3a:  d_rgb = 12'haea;
          6'h3b:  d_rgb = 12'hafd;
          6'h3c:  d_rgb = 12'h9ff;
          6'h3d:  d_rgb = 12'hddd;
          6'h3e:  d_rgb = 12'h111;
          6'h3f:  d_rgb = 12'h111;
        endcase
      end
  end

// Assign output signals.
assign { r, g, b } = q_rgb;
assign ri_dout     = (!ri_ncs && ri_r_nw) ? q_ri_dout : 8'h00;
assign vram_a      = (sel_vram_a == SEL_VRAM_A_DISPLAY) ? display_a : ri_a;
assign vram_dout   = q_ri_wr_data_buf;
assign nvbl        = ~(vblank & `NVBL_EN);

endmodule

