 
`include "router_pkg.sv"
`include "tb_pkg.sv"

import router_pkg::*;
import tb_pkg::*;

module pkt_rx
	#(
		int unsigned sx, sy
	) (
		input logic clk, arst_n,
		input stats_tracker_c pkt_stats_tracker,
		
		input channel_t flit_from_noc,
		output logic credits_to_noc[NUM_VCS]
	);
	
	channel_t flit_rx_tab_r[NUM_VCS];
	
	
	always_ff @(posedge clk or negedge arst_n) begin
		if (!arst_n) begin
			for (int vc=0; vc<NUM_VCS; vc++) begin
				flit_rx_tab_r[vc] <= '0;
				flit_rx_tab_r[vc].head.ftype <= I;
			end
		end else begin
			if (flit_from_noc.head.ftype == HT) begin
				assert (flit_rx_tab_r[flit_from_noc.head.fvcid].head.ftype == I) else $error("RX flit error");
				pkt_stats_tracker.log_pkt_t_rx_time(flit_from_noc.head.srcx, flit_from_noc.head.srcy, flit_from_noc.head.pkt_id);
				pkt_stats_tracker.log_flit_rx();
				pkt_stats_tracker.log_pkt_rx();
			end else if (flit_from_noc.head.ftype == H) begin
				assert (flit_rx_tab_r[flit_from_noc.head.fvcid].head.ftype == I) else $error("RX flit error");
				flit_rx_tab_r[flit_from_noc.head.fvcid] <= flit_from_noc;
				pkt_stats_tracker.log_flit_rx();
			end else if (flit_from_noc.head.ftype == B) begin
				assert (flit_from_noc.head.payload == flit_rx_tab_r[flit_from_noc.head.fvcid].head.payload+1) else $error("RX flit payload error");
				assert ((flit_from_noc.head.payload > 1 && flit_rx_tab_r[flit_from_noc.head.fvcid].head.ftype == B) || (flit_from_noc.head.payload==1 && flit_rx_tab_r[flit_from_noc.head.fvcid].head.ftype == H)) else $error("RX flit error");
				flit_rx_tab_r[flit_from_noc.head.fvcid] <= flit_from_noc;
				pkt_stats_tracker.log_flit_rx();
			end else if (flit_from_noc.head.ftype == T) begin
				assert (flit_from_noc.head.payload == flit_rx_tab_r[flit_from_noc.head.fvcid].head.payload+1) else $error("RX flit payload error");
				assert ((flit_from_noc.head.payload > 1 && flit_rx_tab_r[flit_from_noc.head.fvcid].head.ftype == B) || (flit_from_noc.head.payload==1 && flit_rx_tab_r[flit_from_noc.head.fvcid].head.ftype == H)) else $error("RX flit error");
				flit_rx_tab_r[flit_from_noc.head.fvcid].head.ftype <= I;
				pkt_stats_tracker.log_pkt_t_rx_time(flit_from_noc.head.srcx, flit_from_noc.head.srcy, flit_from_noc.head.pkt_id);
				pkt_stats_tracker.log_flit_rx();
				pkt_stats_tracker.log_pkt_rx();
			end
		end
	end
	
	
	always_ff @(posedge clk or negedge arst_n) begin
		if (!arst_n) begin
			credits_to_noc <= '{NUM_VCS{'0}};
		end else begin
			credits_to_noc <= '{NUM_VCS{'0}};
			if (flit_from_noc.head.ftype != I)
				credits_to_noc[flit_from_noc.head.fvcid] <= 1;
		end
	end
		
	
endmodule
