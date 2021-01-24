module hiscore (
   input        clk,
   input        ioctl_upload,
   input        ioctl_download,
   input        ioctl_wr,
   input [24:0] ioctl_addr,
   input [7:0] ioctl_dout,
   input [7:0] ioctl_din,
   input [7:0]  ioctl_index,
   output [9:0] ram_address

);

/*
00 00 00 0b 0f 10 01 00
00 00 00 23 0f 04 12 00
[ addr    ] len start end pad
addr -> address of ram (in memory map)
len -> how many bytes
start -> wait for this value at start
end -> wait for this value at end
*/

assign ram_address = ram_addr[9:0];
   // save the config into a chunk of memory
reg [7:0] ioctl_dout_r;
reg [7:0] ioctl_dout_r2;
reg [7:0] ioctl_dout_r3;

reg [3:0] counter = 4'b0;
reg [23:0] ram_addr;
wire [23:0] addr_base;
wire [7:0] length;
wire [7:0] start_val;
wire [7:0] end_val;

always @(posedge clk)
begin
if(ioctl_wr & ~ioctl_addr[2] & ~ioctl_addr[1] & ~ioctl_addr[0]) ioctl_dout_r <= ioctl_dout;
if(ioctl_wr & ~ioctl_addr[2] & ~ioctl_addr[1] &  ioctl_addr[0]) ioctl_dout_r2 <= ioctl_dout;
if(ioctl_wr & ~ioctl_addr[2] & ioctl_addr[1] & ~ioctl_addr[0]) ioctl_dout_r3 <= ioctl_dout;
    if (ioctl_wr & ioctl_download)
$display("HISCORE ioctl_addr %x %b ioctl_dout %x ioctl_dout_r %x", ioctl_addr,ioctl_addr[2:0],ioctl_dout,ioctl_dout_r);
if (ioctl_download & ioctl_wr & ~ioctl_addr[2] &  ioctl_addr[1] & ioctl_addr[0])
$display("HI HISCORE ioctl_addr %x %b ioctl_dout_r2 %x ioctl_dout_r3 %x ioctl_dout ", ioctl_addr,ioctl_addr[2:0],ioctl_dout_r2,ioctl_dout_r3,ioctl_dout);
end

dpram#(
.addr_width_g(4),
.data_width_g(24) )
address_table(
.address_a(ioctl_addr[6:3]),
.clock_a(clk),
.data_a({ioctl_dout_r2,  ioctl_dout_r3, ioctl_dout}), // ignore first byte
.wren_a(ioctl_download & ioctl_wr & ~ioctl_addr[2] &  ioctl_addr[1] & ioctl_addr[0] & (ioctl_index==3)),
.clock_b(clk),
.q_b(addr_base),
.address_b(counter)
);

dpram#(.addr_width_g(4),.data_width_g(8))
length_table(
.address_a(ioctl_addr[6:3]),
.clock_a(clk),
.data_a(ioctl_dout),
.wren_a(ioctl_download& ioctl_wr & ioctl_addr[2] & ~ioctl_addr[1] & ~ioctl_addr[0]& (ioctl_index==3)), // ADDR b100
.clock_b(clk),
.q_b(length),
.address_b(counter)
);
dpram#(.addr_width_g(4),.data_width_g(8))
startdata_table(
.address_a(ioctl_addr[6:3]),
.clock_a(clk),
.data_a(ioctl_dout),
.wren_a(ioctl_download& ioctl_wr & ioctl_addr[2] & ~ioctl_addr[1] & ioctl_addr[0]& (ioctl_index==3)), // ADDR b101
.clock_b(clk),
.q_b(start_val),
.address_b(counter)
);
dpram#(.addr_width_g(4),.data_width_g(8))
enddata_table(
.address_a(ioctl_addr[6:3]),
.clock_a(clk),
.data_a(ioctl_dout),
.wren_a(ioctl_download& ioctl_wr & ioctl_addr[2] & ioctl_addr[1] & ~ioctl_addr[0]& (ioctl_index==3)), // ADDR b110
.q_b(end_val),
.address_b(counter)
);

reg [24:0]old_io_addr;

reg [24:0]  base_io_addr;
reg [24:0] end_addr;

// 
//  generate addresses to read high score
//  from game memory. Base addresses off
//  ioctl_address
// 
// 
always @(posedge clk) begin

end_addr <= addr_base + length - 1'b1;

if (ioctl_upload) begin
   if (ioctl_addr==25'b0) begin
      base_io_addr<=24'b0;
      counter<=4'b0;
   end
   if (old_io_addr!=ioctl_addr && ram_addr==end_addr[23:0])
   begin
      counter<=counter+1'b1;
      base_io_addr<=ioctl_addr+1'b1;
   end

   ram_addr<= addr_base + (ioctl_addr - base_io_addr);
end
 
old_io_addr<=ioctl_addr;

 
end

//
// Save the hi score into memory so we can wait and insert
// it into game memory at the right time
//


dpram#(.addr_width_g(5),.data_width_g(8))
hiscoredata (
.address_a(ioctl_addr[4:0]),
.clock_a(clk),
.data_a(ioctl_dout),
.wren_a(ioctl_download& ioctl_wr & (ioctl_index==4)), 
//.q_b(),
//.address_b()
);


//
// loop through and check to see when memory matches
//


endmodule

