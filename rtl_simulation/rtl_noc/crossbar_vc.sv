`include "router_pkg.sv"
import router_pkg::*;

module crossbar_vc #(
	parameter PORT_BANDWIDTH = CH_BITS
	) (
	input logic [PORT_BANDWIDTH-1:0] inport [NUM_PORTS][NUM_VCS],
	input [1:0] p_sel [NUM_PORTS],
	input [VC_ID_BITS-1:0] vc_sel [NUM_PORTS],
	output logic [PORT_BANDWIDTH-1:0] outport [NUM_PORTS]
	);
	
	logic [PORT_BANDWIDTH-1:0] inport_i [NUM_PORTS];
	
	//VC multiplexing
	always_comb 
		for(int unsigned ip=0; ip<NUM_PORTS; ip++)
			inport_i[ip] = inport[ip][vc_sel[ip]];
			
	
	//port multiplexing
	always_comb begin
			for(int unsigned op=0; op<NUM_PORTS; op++) 
				if(p_sel[op] < op)
					outport[op] = inport_i[p_sel[op]];
				else
					outport[op] = inport_i[p_sel[op]+1];
	end
	
endmodule
