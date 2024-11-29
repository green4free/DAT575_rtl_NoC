`include "router_pkg.sv"
import router_pkg::*;

module data_web (
	output logic [NOC_LINK_W-1:0] inport_data [MAX_X][MAX_Y][NUM_PORTS-1],
	input logic [NOC_LINK_W-1:0] outport_data [MAX_X][MAX_Y][NUM_PORTS-1]
	);
	
	logic [NOC_LINK_W-1:0] out_north_flits[-1:MAX_X-1][-1:MAX_Y-1];
	logic [NOC_LINK_W-1:0] out_east_flits[-1:MAX_X-1][-1:MAX_Y-1];
	logic [NOC_LINK_W-1:0] out_south_flits[-1:MAX_X-1][-1:MAX_Y-1];
	logic [NOC_LINK_W-1:0] out_west_flits[-1:MAX_X-1][-1:MAX_Y-1];
	
	genvar x, y;
	generate
		for(x=0; x<MAX_X; x++) begin : data_web_x
			for(y=0; y<MAX_Y; y++) begin : data_web_y
				assign inport_data[x][y] = {out_south_flits[x][y-1], out_west_flits[x][y], out_north_flits[x][y], out_east_flits[x-1][y]};
				
				assign out_west_flits[x-1][y] = outport_data[x][y][3];
				assign out_south_flits[x][y] = outport_data[x][y][2];
				assign out_east_flits[x][y] = outport_data[x][y][1];
				assign out_north_flits[x][y-1] = outport_data[x][y][0];
			end
		end
	endgenerate
	
	generate
		for(y=-1; y<signed '(MAX_Y); y++) begin	: zero_E_W_credits_flits
			assign out_east_flits[-1][y] = '0;	    
			assign out_west_flits[MAX_X-1][y] = '0;
		end
	endgenerate
	
	generate
		for(x=-1; x<signed '(MAX_Y); x++) begin : zero_N_S_credits_flits
			assign out_south_flits[x][-1] = '0;
			assign out_north_flits[x][MAX_Y-1] = '0;
		end
	endgenerate
	
endmodule
