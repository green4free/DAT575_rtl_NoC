//`include "router_pkg.sv"
import router_pkg::*;

module ctrl_web (
	input logic [CH_STATUS_BITS-1:0] outport_flit_status [MAX_X][MAX_Y][NUM_PORTS-1],
	input logic out_credits [MAX_X][MAX_Y][NUM_PORTS-1][NUM_VCS],
	
	output logic [CH_STATUS_BITS-1:0] inport_flit_status [MAX_X][MAX_Y][NUM_PORTS-1],
	output logic in_credit [MAX_X][MAX_Y][NUM_PORTS-1][NUM_VCS]
	);
	
	logic [CH_STATUS_BITS-1:0] out_north_flits[-1:MAX_X-1][-1:MAX_Y-1];
	logic [CH_STATUS_BITS-1:0] out_east_flits[-1:MAX_X-1][-1:MAX_Y-1];
	logic [CH_STATUS_BITS-1:0] out_south_flits[-1:MAX_X-1][-1:MAX_Y-1];
	logic [CH_STATUS_BITS-1:0] out_west_flits[-1:MAX_X-1][-1:MAX_Y-1];
	
	logic out_north_credits[-1:MAX_X-1][-1:MAX_Y-1][0:NUM_VCS-1];
	logic out_east_credits[-1:MAX_X-1][-1:MAX_Y-1][0:NUM_VCS-1];
	logic out_south_credits[-1:MAX_X-1][-1:MAX_Y-1][0:NUM_VCS-1];
	logic out_west_credits[-1:MAX_X-1][-1:MAX_Y-1][0:NUM_VCS-1];
	
	genvar x, y;
	generate 
		for(x=0; x<MAX_X; x++) begin : data_web_x
			for(y=0; y<MAX_Y; y++) begin : data_web_y
				assign inport_flit_status[x][y] = {out_south_flits[x][y-1], out_west_flits[x][y], out_north_flits[x][y], out_east_flits[x-1][y]};
				
				assign out_west_flits[x-1][y] = outport_flit_status[x][y][3];
				assign out_south_flits[x][y] = outport_flit_status[x][y][2];
				assign out_east_flits[x][y] = outport_flit_status[x][y][1];
				assign out_north_flits[x][y-1] = outport_flit_status[x][y][0];
				
				assign out_west_credits[x-1][y] = out_credits[x][y][3];  //{RWSEN}
				assign out_south_credits[x][y] = out_credits[x][y][2];	//{RWSEN}
				assign out_east_credits[x][y] = out_credits[x][y][1];	//{RWSEN}
				assign out_north_credits[x][y-1] = out_credits[x][y][0]; //{RWSEN} 
				
				assign in_credit[x][y] = {out_south_credits[x][y-1], out_west_credits[x][y], out_north_credits[x][y], out_east_credits[x-1][y]}; 
			end
		end
	endgenerate
	
	
	generate
		for(y=-1; y<signed '(MAX_Y); y++) begin	: zero_E_W_credits_flits
			assign out_east_flits[-1][y] = '0;	    
			assign out_west_flits[MAX_X-1][y] = '0;
			
			assign out_east_credits[-1][y] = '{NUM_VCS{'0}};		    
			assign out_west_credits[MAX_X-1][y] = '{NUM_VCS{'0}};
		end
	endgenerate
	
	generate
		for(x=-1; x<signed '(MAX_Y); x++) begin : zero_N_S_credits_flits
			assign out_south_flits[x][-1] = '0;
			assign out_north_flits[x][MAX_Y-1] = '0;
			
			assign out_south_credits[x][-1] = '{NUM_VCS{'0}};
			assign out_north_credits[x][MAX_Y-1] = '{NUM_VCS{'0}};
		end
	endgenerate
	
			
endmodule
