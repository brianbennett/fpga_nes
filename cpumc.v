///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: cpumc
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 08/21/2010
//
// Description:
// 
// CPU Memory Controller.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module cpumc
(
  input  wire        clk,         // 50MHz system clock signal
  input  wire        wr,          // write enable signal
  input  wire [15:0] addr,        // 16-bit memory address
  input  wire [ 7:0] din,         // data input bus
  output reg  [ 7:0] dout,        // data output bus
  output reg         invalid_req  // invalid request signal (1 on error, 0 on success)
);

wire [10:0] ram_addr;
wire [ 7:0] ram_rd_data;
reg         ram_wr;

wire [13:0] prgrom_lo_addr;
wire [ 7:0] prgrom_lo_rd_data;
reg         prgrom_lo_wr;

wire [13:0] prgrom_hi_addr;
wire [ 7:0] prgrom_hi_rd_data;
reg         prgrom_hi_wr;

// CPU Memory Map
//   0x0000 - 0x1FFF RAM           (0x0800 - 0x1FFF mirrors 0x0000 - 0x07FF)
//   0x2000 - 0x401F I/O Regs      (0x2008 - 0x3FFF mirrors 0x2000 - 0x2007)
//   0x4020 - 0x5FFF Expansion ROM (currently unsupported)
//   0x6000 - 0x7FFF SRAM          (currently unsupported)
//   0x8000 - 0xBFFF PRG-ROM LO
//   0xC000 - 0xFFFF PRG-ROM HI

// Block ram instance for "RAM" memory range (0x0000 - 0x1FFF).  0x0800 - 0x1FFF mirrors 0x0000 -
// 0x07FF, so we only need 2048 bytes of physical block ram.
single_port_ram_sync #(.ADDR_WIDTH(11),
                       .DATA_WIDTH(8)) ram(
  .clk(clk),
  .we(ram_wr),
  .addr_a(ram_addr),
  .din_a(din),
  .dout_a(ram_rd_data)
);

assign ram_addr = addr[10:0];

// Block ram instance for "PRG-ROM LO" memory range (0x8000 - 0xBFFF).
single_port_ram_sync #(.ADDR_WIDTH(14),
                       .DATA_WIDTH(8)) prgrom_lo(
  .clk(clk),
  .we(prgrom_lo_wr),
  .addr_a(prgrom_lo_addr),
  .din_a(din),
  .dout_a(prgrom_lo_rd_data)
);

assign prgrom_lo_addr = addr[13:0];

// Block ram instance for "PRG-ROM HI" memory range (0xC000 - 0xFFFF).
single_port_ram_sync #(.ADDR_WIDTH(14),
                       .DATA_WIDTH(8)) prgrom_hi(
  .clk(clk),
  .we(prgrom_hi_wr),
  .addr_a(prgrom_hi_addr),
  .din_a(din),
  .dout_a(prgrom_hi_rd_data)
);

assign prgrom_hi_addr = addr[13:0];

always @*
  begin
    ram_wr       = 1'b0;
    prgrom_lo_wr = 1'b0;
    prgrom_hi_wr = 1'b0;

    invalid_req  = 1'b0;

    if (addr[15:13] == 0)
      begin
        // RAM range (0x0000 - 0x1FFF).
        dout   = ram_rd_data;
        ram_wr = wr;
      end
    else if (addr[15:14] == 2'b10)
      begin
        // PRG-ROM LO range (0x8000 - 0xBFFF).
        dout         = prgrom_lo_rd_data;
        prgrom_lo_wr = wr;
      end
    else if (addr[15:14] == 2'b11)
      begin
        // PRG-ROM HI range (0xC000 - 0xFFFF).
        dout         = prgrom_hi_rd_data;
        prgrom_hi_wr = wr;
      end
    else
      begin
        dout        = 8'hcd;
        invalid_req = 1'b1;
      end
  end

endmodule

