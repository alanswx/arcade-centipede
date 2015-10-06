
module ram(input [9:0] a,
	   input [7:0] 	din,
	   output [7:0] dout,
	   input 	cs_n,
   	   input 	we_n);

   reg [7:0] mem[0:1023];
   reg [7:0] d;
   wire [9:0] addr;
   
`ifdef SIMULATION
   integer    j;
   
   initial
     begin
	for (j = 0; j < 1024; j = j + 1)
	  mem[j] = 0;
     end
`endif

   wire ram_read, ram_write;
   assign ram_read = ~cs_n & we_n;
   assign ram_write = ~cs_n & ~we_n;

   assign dout = d;

   always @(a or ram_read)
     if (ram_read)
       d = mem[a];

   always @(a or ram_write)
     if (ram_write)
       mem[a] = din;

endmodule