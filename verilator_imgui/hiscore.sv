module hiscore (
   input        clk,
   input        ioctl_upload,
   input        ioctl_download,
   input        ioctl_wr,
   input [24:0] ioctl_addr,
   input [7:0] ioctl_dout,
   input [7:0] ioctl_din,
   input [7:0]  ioctl_index,
   output [9:0] ram_address,
   output [7:0] data_to_ram
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
reg [24:0] ram_addr;
wire [23:0] addr_base;
wire [7:0] length;
wire [7:0] start_val;
wire [7:0] end_val;

reg [3:0] total_entries=4'b0;

always @(posedge clk)
begin
    if(ioctl_wr & ~ioctl_addr[2] & ~ioctl_addr[1] & ~ioctl_addr[0]) ioctl_dout_r <= ioctl_dout;
    if(ioctl_wr & ~ioctl_addr[2] & ~ioctl_addr[1] &  ioctl_addr[0]) ioctl_dout_r2 <= ioctl_dout;
    if(ioctl_wr & ~ioctl_addr[2] & ioctl_addr[1] & ~ioctl_addr[0]) ioctl_dout_r3 <= ioctl_dout;

    //  keep track of the largest entry
    if (ioctl_download & (ioctl_index==3))
    	total_entries<=ioctl_addr[6:3];

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

reg [1:0] state = 2'b0;

reg [24:0] local_addr;
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
      base_io_addr<=25'b0;
      counter<=4'b0;
   end
   if (old_io_addr!=ioctl_addr && ram_addr==end_addr[24:0])
   begin
      counter<=counter+1'b1;
      base_io_addr<=ioctl_addr+1'b1;
   end

   ram_addr<= addr_base + (ioctl_addr - base_io_addr);
end
//
// loop through and check to see when memory matches
//
else if (done_downloading==1'b1 && ioctl_upload==1'b0) begin
   case (state)
       // start with counter == 0?
       2'b00: // start
         // setup beginning addr 
          begin
             state = 2'b01;
             local_addr<=25'b0;
              base_io_addr<=25'b0;
             ram_addr<= addr_base;
          end
       2'b01:
         // check beginning
             if (ioctl_din==start_val)
             begin
                 $display("HI HISCORE start_val==ioctl_din");
		state = 2'b10;
                // setup ending addr 
                ram_addr<= end_addr;
             end
        // check end
       2'b10:
              $display("HI HISCORE ?end_val==ioctl_din ioctl_din %x end_val %x ram_addr %x",ioctl_din,end_val,ram_addr);
             if (ioctl_din==end_val)
             begin
                 $display("HI HISCORE end_val==ioctl_din");
                   // check to see if we are at the end..
                if (counter==total_entries)
                begin
                   state = 2'b11;
                   counter<=0;
                end
                else begin
		   counter<=counter+1'b1;
                   state = 2'b00;
                end
             end
       2'b11:
            begin
                local_addr<= local_addr+1'b1;
                if (ram_addr==end_addr[24:0])
                begin
                   counter<=counter+1'b1;
                   base_io_addr<=ioctl_addr+1'b1;
                end
                ram_addr<= addr_base + (local_addr - base_io_addr);
            end
   endcase
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
.wren_a(ioctl_download & ioctl_wr & (ioctl_index==4)), 
.q_b(data_to_ram),
.address_b(local_addr)
);

reg [24:0] last_address;
reg [7:0] last_index;
reg done_downloading=0;
reg last_ioctl_download=0;
always @(posedge clk) begin
  if (ioctl_download & ioctl_wr & (ioctl_index==4))
	last_address<=ioctl_addr;
  if (last_ioctl_download!=ioctl_download && ioctl_download==1'b0 && (last_index==4))
	done_downloading=1'b1;
  last_ioctl_download<=ioctl_download;
  last_index<=ioctl_index;
end


endmodule

