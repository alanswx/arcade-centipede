//
//
//

`timescale 1ns/1ns

`define SDL_DISPLAY

module top(VGA_R,VGA_B,VGA_G,VGA_HS,VGA_VS,reset,clk_sys,clk_vid,ioctl_upload,ioctl_download,ioctl_addr,ioctl_dout,ioctl_din,ioctl_index,ioctl_wait,ioctl_wr);

   input clk_sys/*verilator public_flat*/;
   input clk_vid/*verilator public_flat*/;
   input reset/*verilator public_flat*/;

   output [7:0] VGA_R/*verilator public_flat*/;
   output [7:0] VGA_G/*verilator public_flat*/;
   output [7:0] VGA_B/*verilator public_flat*/;

   output VGA_HS;
   output VGA_VS;

   input        ioctl_upload;
   input        ioctl_download;
   input        ioctl_wr;
   input [24:0] ioctl_addr;
   input [7:0] ioctl_dout;
   output [7:0] ioctl_din;
   input [7:0]  ioctl_index;
   output  reg     ioctl_wait=1'b0;

   wire clk = clk_sys;


   wire [8:0] rgb;
   wire       csync, hsync, vsync, hblank, vblank;
   wire [7:0] audio;
   wire [3:0] led/*verilator public_flat*/;

   reg [7:0]  trakball/*verilator public_flat*/;
   reg [7:0]  joystick/*verilator public_flat*/;
   reg [7:0]  sw1/*verilator public_flat*/;
   reg [7:0]  sw2/*verilator public_flat*/;
   reg [9:0]  playerinput/*verilator public_flat*/;
  
wire [9:0]ram_address;
 
   centipede uut(
		 .clk_12mhz(clk),
 		 .reset(reset),
		 .playerinput_i(playerinput),
		 .trakball_i(trakball),
		 .joystick_i(joystick),
		 .sw1_i(sw1),
		 .sw2_i(sw2),
		 .led_o(led),
		 .rgb_o(rgb),
		 .sync_o(csync),
		 .hsync_o(hsync),
		 .vsync_o(vsync),
		 .hblank_o(hblank),
		 .vblank_o(vblank),
		 .audio_o(audio),
		.clk_6mhz_o(),
	
		.ram_address(ram_address),
		.ram_data(ioctl_din)
		 );

always @(posedge clk) begin
if (ioctl_upload)
    $display("ioctl_addr %x ram_address %x ioctl_din %x ", ioctl_addr, ram_address ,ioctl_din );
end

   wire [2:0]  vgaBlue;
   wire [2:0]  vgaGreen;
   wire [2:0]  vgaRed;

   assign VGA_R = {vgaRed,vgaRed,vgaRed[2:1]};
   assign VGA_G = {vgaGreen,vgaGreen,vgaGreen[2:1]};
   assign VGA_B = {vgaBlue,vgaBlue,vgaBlue[2:1]};
   assign vgaBlue  = rgb[8:6];
   assign vgaGreen = rgb[5:3];
   assign vgaRed   = rgb[2:0];

   assign VGA_VS=~vsync; 
   assign VGA_HS=~hsync; 
  

hiscore hi (
   .clk(clk),
   .ioctl_upload(ioctl_upload),
   .ioctl_download(ioctl_download),
   .ioctl_wr(ioctl_wr),
   .ioctl_addr(ioctl_addr),
   .ioctl_dout(ioctl_dout),
   .ioctl_din(ioctl_din),
   .ioctl_index(ioctl_index),
   .ram_address(ram_address)

);
 
endmodule // ff_tb

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
reg [23:0] addr_base;
reg [7:0] offset;
wire [7:0] length;

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

dpram_dc#(
	.addr_width_g(4),
	.data_width_g(24) )
address_table(
	.address_a(ioctl_addr[6:3]),
	.clock_a(clk),
	.data_a({ioctl_dout_r2,  ioctl_dout_r3, ioctl_dout}), // ignore first byte
	.wren_a(ioctl_download & ioctl_wr & ~ioctl_addr[2] &  ioctl_addr[1] & ioctl_addr[0]),	
	.clock_b(clk),
	.q_b(addr_base),
	.address_b(counter)
	);

dpram_dc#(.addr_width_g(4),.data_width_g(8))
length_table(
	.address_a(ioctl_addr[6:3]),
	.clock_a(clk),
	.data_a(ioctl_dout),
	.wren_a(ioctl_download& ioctl_wr & ioctl_addr[2] & ~ioctl_addr[1] & ~ioctl_addr[0]), // ADDR b100	
	.clock_b(clk),
	.q_b(length),
	.address_b(counter)
);
dpram_dc#(.addr_width_g(4),.data_width_g(8))
startdata_table(
	.address_a(ioctl_addr[6:3]),
	.clock_a(clk),
	.data_a(ioctl_dout),
	.wren_a(ioctl_download& ioctl_wr & ioctl_addr[2] & ~ioctl_addr[1] & ioctl_addr[0]), // ADDR b101	
	.clock_b(clk),
	.q_b(start_val),
	.address_b(counter)
);
dpram_dc#(.addr_width_g(4),.data_width_g(8))
enddata_table(
	.address_a(ioctl_addr[6:3]),
	.clock_a(clk),
	.data_a(ioctl_dout),
	.wren_a(ioctl_download& ioctl_wr & ioctl_addr[2] & ioctl_addr[1] & ~ioctl_addr[0]), // ADDR b110	
	.q_b(end_val),
	.address_b(counter)
);


always @(posedge clk) begin
 if (ioctl_upload) begin
    ram_addr <= addr_base + offset;

    if (offset==length-2)
	counter<=counter+1'b1;

    if (offset< length -1 )  /* length is 1 too big? */
        offset<=offset +1'b1;
    else begin
        offset<=8'b0;
    end
    $display("ioctl_addr %x addr_base %x offset %x  counter %x length %x ram_addr %x", ioctl_addr, addr_base,offset,counter,length,ram_addr);
 end
end

endmodule
