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
  input  wire        clk,   // 50MHz system clock signal
  input  wire        wr,    // write enable signal
  input  wire [15:0] addr,  // 16-bit memory address
  input  wire [ 7:0] din,   // data input bus
  output reg  [ 7:0] dout   // data output bus
);

wire [13:0] prgrom_hi_addr;
wire [ 7:0] prgrom_hi_rd_data;
reg         prgrom_hi_wr;

// CPU Memory Map
//   0x0000 - 0x1FFF RAM           (0x0800 - 0x1FFF mirrors 0x0000 - 0x07FF)
//   0x2000 - 0x401F I/O Regs      (0x2008 - 0x3FFF mirrors 0x2000 - 0x2007)
//   0x4020 - 0x5FFF Expansion ROM (currently unsupported)
//   0x6000 - 0x7FFF SRAM          (currently unsupported)
//   0x8000 - 0xBFFF PRG-ROM LO    (currently mirrors PRG-ROM HI)
//   0xC000 - 0xFFFF PRG-ROM HI

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
    dout         = 8'h00;
    prgrom_hi_wr = 1'b0;

    if (addr[15] == 1'b1)
      begin
        // PRG-ROM HI range (0xC000 - 0xFFFF).
        dout         = prgrom_hi_rd_data;
        prgrom_hi_wr = wr;
      end
  end

endmodule

