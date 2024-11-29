`include "router_pkg.sv"
import router_pkg::*;

module rev_xbar_vc #(
	parameter PORT_BANDWIDTH = CH_BITS
	) (
	input logic [PORT_BANDWIDTH-1:0] inport [NUM_PORTS][NUM_VCS],
	input [1:0] p_sel [NUM_PORTS][NUM_VCS],
	input [VC_ID_BITS-1:0] vc_sel [NUM_PORTS][NUM_VCS],
	output logic [PORT_BANDWIDTH-1:0] outport [NUM_PORTS][NUM_VCS]
	);
	
	
	always_comb begin
		for(int unsigned p=0; p<NUM_PORTS; p++) 
			for(int unsigned v=0; v<NUM_VCS; v++) begin
				if(p_sel[p][v]>=p)
					outport[p][v] = inport[p_sel[p][v]+1][vc_sel[p][v]];
				else
					outport[p][v] = inport[p_sel[p][v]][vc_sel[p][v]];
				
			end
	end
	
endmodule
