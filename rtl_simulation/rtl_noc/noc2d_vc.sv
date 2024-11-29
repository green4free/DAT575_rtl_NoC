`include "router_pkg.sv"
import router_pkg::*;

module noc2d_vc (
	input logic clk, arst_n,
	
	input logic [CH_BITS-1:0] inport[MAX_X][MAX_Y],
	output logic outcredit[MAX_X][MAX_Y][NUM_VCS],
	
	output  logic [CH_BITS-1:0] outport[MAX_X][MAX_Y],
	input logic incredit[MAX_X][MAX_Y][NUM_VCS]
	);
	
		
	logic [NOC_LINK_W-1:0] inport_data[MAX_X][MAX_Y][NUM_PORTS-1];
	logic [NOC_LINK_W-1:0] outport_data[MAX_X][MAX_Y][NUM_PORTS-1];
	data_web data_web_i (
		inport_data,
		outport_data
	);	
	
	logic [CH_STATUS_BITS-1:0] inport_flit_status[MAX_X][MAX_Y][NUM_PORTS-1];
	logic out_credits_w[MAX_X][MAX_Y][NUM_PORTS-1][NUM_VCS];
	logic [CH_STATUS_BITS-1:0] outport_flit_status[MAX_X][MAX_Y][NUM_PORTS-1];
	logic in_credits_w[MAX_X][MAX_Y][NUM_PORTS-1][NUM_VCS];
	ctrl_web ctrl_web_i (
		outport_flit_status,
		out_credits_w,
		inport_flit_status,
		in_credits_w
	);
	
	channel_t inport_noc [MAX_X][MAX_Y][NUM_PORTS];
	channel_t outport_noc [MAX_X][MAX_Y][NUM_PORTS];	
	
	logic out_credits_noc[MAX_X][MAX_Y][NUM_PORTS][NUM_VCS];
	logic in_credits_noc[MAX_X][MAX_Y][NUM_PORTS][NUM_VCS];	
	
	genvar x, y, p;
	generate 
		for(x=0; x<MAX_X; x++) begin : gen_wire_x
			for(y=0; y<MAX_Y; y++) begin : gen_wire_y
				for(p=0; p<NUM_PORTS-1; p++) begin : gen_wire_p
				
					assign inport_noc[x][y][p] = { inport_flit_status[x][y][p], inport_data[x][y][p] };
					
					assign { outport_flit_status[x][y][p],  outport_data[x][y][p] } = outport_noc[x][y][p];
					
					assign out_credits_w[x][y][p] = out_credits_noc[x][y][p];
					
					assign in_credits_noc[x][y][p] = in_credits_w[x][y][p];
				
				end
				
				assign inport_noc[x][y][4] = inport[x][y];
				assign outport[x][y] = outport_noc[x][y][4];
				assign outcredit[x][y] = out_credits_noc[x][y][4];
				assign in_credits_noc[x][y][4] = incredit[x][y];
			end
		end
		
		
		for(x=0; x<MAX_X; x++) begin : gen_x
			for(y=0; y<MAX_Y; y++) begin : gen_y
				
				router_vc router_i (
					x[DIM_BITS-1:0],
					y[DIM_BITS-1:0],
					clk, arst_n, 
					
					inport_noc[x][y], //{NESWR}
					out_credits_noc[x][y],
					
					outport_noc[x][y],
					in_credits_noc[x][y]
				);
		
			end
		end
	endgenerate
	
	
endmodule


