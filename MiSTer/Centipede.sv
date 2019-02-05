//============================================================================
//  Centipede port to MiSTer
//  Copyright (c) 2019 alanswx
//
//   
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR
);

//`define SOUND_DBG
assign VGA_SL=0;

assign VGA_F1=0;
assign CE_PIXEL=1;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

//assign VIDEO_ARX = status[9] ? 8'd16 : 8'd4;
//assign VIDEO_ARY = status[9] ? 8'd9  : 8'd3;


assign VIDEO_ARX = 4;
assign VIDEO_ARY = 3;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 1;
assign LED_USER  = ioctl_download;

`include "build_id.v"
localparam CONF_STR = {
	"A.CENTIPED;;",
	"-;",
	"-;",
	"-;",
	"-;",
	"T6,Reset;",
	"J,Throw,Start 1P,Start 2P;",
	"V,v",`BUILD_DATE
};


wire [31:0] status;
wire  [1:0] buttons;
wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;
wire  [7:0] ioctl_index;
reg         ioctl_wait=0;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire  [15:0] sd_buff_dout;
wire  [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire        forced_scandoubler;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire reset;
assign reset = (RESET | status[0] | status[6] | buttons[1] | ioctl_download);


hps_io #(.STRLEN(($size(CONF_STR)>>3) )/*, .PS2DIV(1000), .WIDE(0)*/) hps_io
(
	.clk_sys(CLK_VIDEO/*clk_sys*/),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.joystick_0(joystick_0),
	.joystick_analog_0(analog_joy_0),

	.joystick_1(joystick_1),
	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.status(status),
	.status_in({status[31:8],region_req,status[5:0]}),
	.status_set(region_set),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_wait),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	
	
	.ps2_key(ps2_key)
	//.ps2_mouse(ps2_mouse)
);


wire [15:0] analog_joy_0;
wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge CLK_VIDEO) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up          <= pressed; // up
			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h029: btn_fire        <= pressed; // space
			'h014: btn_fire        <= pressed; // ctrl

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
			'h00C: btn_test <= pressed; // F4
		endcase
	end
end

reg btn_up    = 0;
reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_fire  = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;
reg btn_test = 0;

wire m_up     =  btn_up    | joy[3];
wire m_down   =  btn_down  | joy[2];
wire m_left   =  btn_left  | joy[1];
wire m_right  =  btn_right | joy[0];
wire m_fire   =  btn_fire  | joy[4];

wire m_start1 = btn_one_player  | joy[5];
wire m_start2 = btn_two_players | joy[6];
wire m_coin   = m_start1 | m_start2;

wire [7:0] joyx=8'd256-($signed(analog_joy_0[7:0])+8'd128); 
wire [7:0] joyy=8'd256-($signed(analog_joy_0[15:8])+8'd128); 


   wire auto_coin_n, auto_start_n, auto_throw_n;

   wire cga_hsync, cga_vsync, cga_csync, cga_hblank, cga_vblank;
   wire [8:0] cga_rgb;

   wire [3:0] led_o;
   wire [7:0] trakball_i;
   wire [7:0] joystick_i;
   wire [7:0] sw1_i;
   wire [7:0] sw2_i;
   wire [9:0] playerinput_i;
   wire [7:0] audio;

  

   wire       clk_pix;

   assign trakball_i = 0;
   assign sw1_i = 8'h54;
   assign sw2_i = 8'b0;

   wire       coin_r, coin_c, coin_l, self_test, cocktail, slam, start1, start2, fire2, fire1;

   assign coin_r = 1;
   assign coin_c = 1;
   assign coin_l = 1;
   assign self_test = 1;
   assign cocktail = 0;
   assign slam = 1;
   assign start1 = 1;
   assign start2 = 1;
   assign fire2 = 1;
   assign fire1 = 1;

//   assign playerinput_i = { coin_r, coin_c, coin_l, self_test, cocktail, slam, ~mstart1, ~mstart2, 1'b1, ~mfire };
   assign playerinput_i = { 1'b1, 1'b1, ~m_coin, ~btn_test, 1'b0, 1'b1, ~m_start1, ~m_start2, 1'b1, ~m_fire };
	
	
	assign joystick_i = { ~m_right,~m_left,~m_down,~m_up, ~m_right,~m_left,~m_down,~m_up};
//   assign playerinput_i = 10'b111_101_11_11;

   // game & cpu
   centipede uut(
		 .clk_12mhz(clk12m),
 		 .reset(reset),
		 .playerinput_i(playerinput_i),
		 .trakball_i(trakball_i),
		 .joystick_i(joystick_i),
		 .sw1_i(sw1_i),
		 .sw2_i(sw2_i),
		 .led_o(led_o),
		 .audio_o(audio),

		 .rgb_o(rgb),
		 .sync_o(),
		 .hsync_o(hsync),
		 .vsync_o(vsync),
		 .hblank_o(hblank),
		 .vblank_o(vblank)
		 );



			
///////////////////////////////////////////////////
//wire clk_sys, clk_ram, clk_ram2, clk_pixel, locked;
wire clk_sys,locked,clk12m,clk6m;
wire hsync,vsync;

wire [8:0] rgb;

wire hblank,vblank;

			
//assign VGA_B = 8'h00;//{ rgb[8], rgb[7], rgb[6],5'b00000 };
//assign VGA_G = 8'hFF;//{ vga_rgb[5], vga_rgb[4], vga_rgb[3],5'b00000 };
//assign VGA_R = 8'h00;//{ rgb[2], rgb[1], rgb[0],5'b00000 };

assign VGA_B = { rgb[8], rgb[7], rgb[6],5'b00000 };
assign VGA_G = { rgb[5], rgb[4], rgb[3],5'b00000 };
assign VGA_R = { rgb[2], rgb[1], rgb[0],5'b00000 };


//assign VGA_R={rgb[2:0],5'b00000};
//assign VGA_G={rgb[5:3],5'b00000};
//assign VGA_B={rgb[7:6],6'b000000};

//assign VGA_R={rgb[2:0],5'b00000};
//assign VGA_G={rgb[5:3],5'b00000};
//assign VGA_B={rgb[7:6],6'b000000};
assign VGA_HS=hsync;
assign VGA_VS=vsync;

assign VGA_DE=~(hblank|vblank);
assign CLK_VIDEO=clk6m;




//assign AUDIO_L= {audio[1],7'b0};
//assign AUDIO_R= {audio[4],7'b0};
//assign AUDIO_L= {1'b0,audio[1] | audio[4],6'b0};
//assign AUDIO_R= {1'b0,audio[1] | audio[4],6'b0};

//assign AUDIO_L= audio;
//assign AUDIO_R= audio;

assign AUDIO_L={audio[1] | audio[4],audio[1] | audio[4],audio[1] | audio[4],audio[1] | audio[4],audio[1] | audio[4],1'b0,1'b0,1'b0,8'b00000000};
assign AUDIO_R={audio[1] | audio[4],audio[1] | audio[4],audio[1] | audio[4],audio[1] | audio[4],audio[1] | audio[4],1'b0,1'b0,1'b0,8'b00000000};



//assign SDRAM_CLK=ram_clock;
pll pll (
	 .refclk ( CLK_50M   ),
	 .rst(0),
	 .locked ( locked    ),        // PLL is running stable
	 .outclk_0    (clk_sys), 		//25
	 .outclk_1     ( clk12m   ),      //12
	 .outclk_2     ( clk6m     )        // 6 MHz
	 );
	 
	 
	 
	 

endmodule
