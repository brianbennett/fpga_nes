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
reg [11:0] q_rgb;               // output color latch (required by vga_sync)
reg [11:0] d_rgb;
reg [ 7:0] q_tile_name;         // name for next tile (index for pattern bytes)
reg [ 7:0] d_tile_name;
reg [ 7:0] q_attribute [1:0];   // attribute byte (ping/pong per tile)
reg [ 7:0] d_attribute [1:0];
reg [ 7:0] q_tile_bit0 [1:0];   // pattern bit0 byte (ping/pong per tile)
reg [ 7:0] d_tile_bit0 [1:0];
reg [ 7:0] q_tile_bit1 [1:0];   // pattern bit1 byte (ping/pong per tile)
reg [ 7:0] d_tile_bit1 [1:0];

reg [13:0] q_ri_addr;           // reg interface addr (updated by writing 0x2006)
reg [13:0] d_ri_addr;
reg        q_ri_addr_byte_sel;  // reg interface tracking if next 0x2006 write is high or low byte
reg        d_ri_addr_byte_sel;
reg [ 7:0] q_ri_dout;           // reg interface output data bus latch (source for 0x2007 reads)
reg [ 7:0] d_ri_dout;
reg [13:0] q_ri_addr_buf;       // reg interface addr buffer (for buffered mem reads/writes)
reg [13:0] d_ri_addr_buf;
reg [ 7:0] q_ri_rd_data_buf;    // reg interface read data buffer (dst for buffered mem reads)
reg [ 7:0] d_ri_rd_data_buf;
reg [ 7:0] q_ri_wr_data_buf;    // reg interface write data buffer (src for buffered mem writes)
reg [ 7:0] d_ri_wr_data_buf;
reg [ 1:0] q_ri_mem_cmd;        // reg interface buffered memory command
reg [ 1:0] d_ri_mem_cmd;
reg        q_ri_mem_rd_rdy;     // reg interface mem command complete signal
reg        d_ri_mem_rd_rdy;
reg        q_ri_ncs;            // reg interface last ncs signal - used for detecting ncs edges

reg        q_bg_en;             // tracks whether user has enabled/disabled background display
reg        d_bg_en;
reg        q_nvbl_en;           // enables /VBL output signal (CPU NMI interrupt)
reg        d_nvbl_en;
reg [ 1:0] q_name_tbl_addr;     // name table address
reg [ 1:0] d_name_tbl_addr;
reg        q_pattern_tbl_addr;  // pattern table address
reg        d_pattern_tbl_addr;
reg        q_addr_incr;         // address increment for register access (0=1, 1=32)
reg        d_addr_incr;
reg [ 1:0] q_vblank;            // vblank state: [1]=last clk vblank, [0]=user read state
reg [ 1:0] d_vblank;

//
// PPU internal RAM.
//
reg [5:0] palette_ram [31:0];

//
// Control signals.
//
reg         sel_vram_a;       // selects vram address bus driver (0 = display, 1 = ri)
reg  [13:0] display_a;        // display address request
reg  [13:0] ri_a;             // register interface address request
reg         wr_palette_ram;   // enable palette ram write
wire [ 5:0] palette_ram_din;  // vram_din equivalent for palette_ram reads
wire        vblank;           // indicates VRAM not being read by display at end of frame

//
// VGA_SYNC: VGA synchronization control block.
//
wire       en;
wire [9:0] vga_x, vga_y;

vga_sync vga_sync_blk(
  .clk(clk),
  .hsync(hsync),
  .vsync(vsync),
  .en(en),
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
        q_attribute[0]     <= 8'h00;
        q_attribute[1]     <= 8'h00;
        q_tile_bit0[0]     <= 8'h00;
        q_tile_bit0[1]     <= 8'h00;
        q_tile_bit1[0]     <= 8'h00;
        q_tile_bit1[1]     <= 8'h00;
        q_ri_addr          <= 14'h0000;
        q_ri_addr_byte_sel <= 1'b1;
        q_ri_dout          <= 8'h00;
        q_ri_addr_buf      <= 14'h0200;
        q_ri_rd_data_buf   <= 8'h00;
        q_ri_wr_data_buf   <= 8'h00;
        q_ri_mem_cmd       <= 2'b00;
        q_ri_mem_rd_rdy    <= 1'b0;
        q_ri_ncs           <= 1'b1;
        q_bg_en            <= 1'b0;
        q_nvbl_en          <= 1'b0;
        q_name_tbl_addr    <= 2'b00;
        q_pattern_tbl_addr <= 1'b0;       
        q_addr_incr        <= 1'b0;
        q_vblank           <= 2'b00;
      end
    else
      begin
        q_rgb              <= d_rgb;
        q_tile_name        <= d_tile_name;
        q_attribute[0]     <= d_attribute[0];
        q_attribute[1]     <= d_attribute[1];
        q_tile_bit0[0]     <= d_tile_bit0[0];
        q_tile_bit0[1]     <= d_tile_bit0[1];
        q_tile_bit1[0]     <= d_tile_bit1[0];
        q_tile_bit1[1]     <= d_tile_bit1[1];
        q_ri_addr          <= d_ri_addr;
        q_ri_addr_byte_sel <= d_ri_addr_byte_sel;
        q_ri_dout          <= d_ri_dout;
        q_ri_addr_buf      <= d_ri_addr_buf;
        q_ri_rd_data_buf   <= d_ri_rd_data_buf;
        q_ri_wr_data_buf   <= d_ri_wr_data_buf;
        q_ri_mem_cmd       <= d_ri_mem_cmd;
        q_ri_mem_rd_rdy    <= d_ri_mem_rd_rdy;
        q_ri_ncs           <= ri_ncs;
        q_bg_en            <= d_bg_en;
        q_nvbl_en          <= d_nvbl_en;
        q_name_tbl_addr    <= d_name_tbl_addr;
        q_pattern_tbl_addr <= d_pattern_tbl_addr;
        q_addr_incr        <= d_addr_incr;
        q_vblank           <= d_vblank;
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
    d_ri_addr_byte_sel = q_ri_addr_byte_sel;
    d_ri_dout          = q_ri_dout;
    d_ri_addr_buf      = q_ri_addr_buf;
    d_ri_rd_data_buf   = q_ri_rd_data_buf;
    d_ri_wr_data_buf   = q_ri_wr_data_buf;
    d_ri_mem_cmd       = q_ri_mem_cmd;
    d_bg_en            = q_bg_en;
    d_nvbl_en          = q_nvbl_en;
    d_name_tbl_addr    = q_name_tbl_addr;
    d_pattern_tbl_addr = q_pattern_tbl_addr;
    d_addr_incr        = q_addr_incr;

    d_ri_mem_rd_rdy    = 1'b0;

    ri_a               = q_ri_addr_buf;
    vram_wr            = 1'b0;
    wr_palette_ram     = 1'b0;

    // q_vblank[1] stores the vblank signal from the previous cycle, to detect vblank edges.
    // q_vblank[0] is the register interface vblank bit (set on vblank rising edge, cleared on
    // vblank falling edge or user read of 0x2000).
    d_vblank[1] = vblank;
    d_vblank[0] = (vblank & ~q_vblank[1]) ? 1'b1 :
                  (~vblank)               ? 1'b0 : q_vblank;

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
                  d_ri_dout = { q_vblank[0], 7'h00 };

                  d_ri_addr_byte_sel = 1'b1;
                  d_vblank[0]        = 1'b0;
                end
              3'h7:  // 0x2007
                begin
                  // Setup buffered read command.
                  d_ri_mem_cmd  = RI_MEM_CMD_RD;
                  d_ri_addr_buf = q_ri_addr;

                  // Move previous read result to output, and update addr for next ri op.
                  d_ri_dout = q_ri_rd_data_buf;
                  d_ri_addr = q_ri_addr + ((q_addr_incr) ? 16'h0020 : 16'h0001);
                end
            endcase
          end
        else
          begin
            // External register write.
            case (ri_sel)
              3'h0:  // 0x2000
                begin
                  d_name_tbl_addr    = ri_din[1:0];
                  d_addr_incr        = ri_din[2];
                  d_pattern_tbl_addr = ri_din[4];
                  d_nvbl_en          = ri_din[7];
                end
              3'h1:  // 0x2001
                begin
                  d_bg_en = ri_din[3];
                end
              3'h6:  // 0x2006
                begin
                  d_ri_addr_byte_sel = ~q_ri_addr_byte_sel;
                  if (q_ri_addr_byte_sel)
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
                  d_ri_addr = q_ri_addr + ((q_addr_incr) ? 16'h0020 : 16'h0001);
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
wire [9:0] x, y;
wire [4:0] tile_x, tile_y, next_tile_x;
wire       border;

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
always @(vram_din        or q_tile_name    or q_attribute[0] or q_attribute[1] or q_tile_bit0[0] or
         q_tile_bit0[1]  or q_tile_bit1[0] or q_tile_bit1[1] or x              or y              or
         tile_x          or tile_y         or next_tile_x    or vblank         or q_bg_en        or
         q_name_tbl_addr or q_pattern_tbl_addr)
  begin
    // Default registers to their current values.
    d_tile_name    = q_tile_name;
    d_attribute[0] = q_attribute[0];
    d_attribute[1] = q_attribute[1];
    d_tile_bit0[0] = q_tile_bit0[0];
    d_tile_bit0[1] = q_tile_bit0[1];
    d_tile_bit1[0] = q_tile_bit1[0];
    d_tile_bit1[1] = q_tile_bit1[1];

    sel_vram_a = SEL_VRAM_A_DISPLAY;
    display_a  = 14'h0000;

    if (q_bg_en && !vblank)
      case (x[2:0])
        3'b000:
          begin
            // Stage 0.  Load next tile's name.
            display_a = { NAME_TABLE[13:12],
                          q_name_tbl_addr,
                          tile_y[4:0],
                          next_tile_x[4:0] };
            d_tile_name = vram_din;
          end
        3'b001:
          begin
            // Stage 1.  Load next tile's attrib byte.
            display_a = { ATTRIBUTE_TABLE[13:12],
                          q_name_tbl_addr,
                          ATTRIBUTE_TABLE[9:6],
                          tile_y[4:2],
                          next_tile_x[4:2] };
            d_attribute[~tile_x[0]] = vram_din;
          end
        3'b010:
          begin
            // Stage 2.  Load bit0 pattern data based on tile name.
            display_a = { PATTERN_TABLE[13],
                          q_pattern_tbl_addr,
                          q_tile_name,
                          1'b0,
                          y[2:0] };
            d_tile_bit0[~tile_x[0]] = vram_din;
          end
        3'b011:
          begin
            // Stage 3.  Load bit1 pattern data based on tile name.
            display_a = { PATTERN_TABLE[13],
                          q_pattern_tbl_addr,
                          q_tile_name,
                          1'b1,
                          y[2:0] };
            d_tile_bit1[~tile_x[0]] = vram_din;
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
wire [3:0] image_palette_idx;
wire [5:0] sys_palette_idx;

assign image_palette_idx = { q_attribute[tile_x[0]] >> { tile_y[1], tile_x[1], 1'b0 },
                             q_tile_bit1[tile_x[0]][~x],
                             q_tile_bit0[tile_x[0]][~x] };
assign sys_palette_idx = (q_bg_en) ? palette_ram[{1'b0, image_palette_idx}] : 6'h00;

//
// Lookup RGB values based on sys_palette_idx.
//
always @*
  begin
    if (!en)
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
assign nvbl        = ~(vblank & q_nvbl_en);

endmodule

