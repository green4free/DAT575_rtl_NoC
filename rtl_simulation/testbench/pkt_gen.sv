`include "router_pkg.sv"
`include "tb_pkg.sv"

import router_pkg::*;
import tb_pkg::*;


program automatic pkt_gen 
	#(
		int unsigned sx, sy,
		int rand_seed,
		bit add_rand_startup_delay
	) (
		input logic clk, arst_n,
		input stats_tracker_c pkt_stats_tracker,
		input packet_traces_c pkt_traces_all,
		
		output pkt_t pkt_to_queue,
		output logic pkt_rdy_to_queue
	);
	
	int start_delay;
	pkt_t pkt_to_send;
	bit pkt_gen_ready = 0;
	bit src_is_active_node;
	
	int unsigned pkt_id_i;
	realtime next_pkt_delay;
	
	initial begin
		void'($urandom(rand_seed));
		start_delay = 1 + $urandom()%100;
		
		@(negedge arst_n)
		pkt_rdy_to_queue = 0;
		src_is_active_node = pkt_traces_all.is_active_node(sx,sy);
		pkt_id_i = 0;
		
		@(posedge arst_n);
		
		if (add_rand_startup_delay) begin
			repeat (start_delay) @(posedge clk);
		end
		
		pkt_gen_ready = 1;
	end
	
	
	
	initial begin
		@(posedge clk);
		@(posedge pkt_gen_ready);
		
		
		while (src_is_active_node) begin
			pkt_to_send = pkt_traces_all.get_pkt_to_send(sx, sy);
			pkt_to_send.pkt_id = pkt_id_i;
			
			pkt_to_queue = pkt_to_send;
			pkt_rdy_to_queue = ~pkt_rdy_to_queue;
			
			pkt_stats_tracker.log_pkt_gen_time(sx,sy,pkt_id_i);
			pkt_stats_tracker.log_pkt_gen();
			pkt_stats_tracker.log_flit_gen(pkt_to_send.flit_count);
			pkt_id_i++;
			
			next_pkt_delay = pkt_to_send.next_pkt_delay * GEN_CLK_PRD * 1ps;
			#next_pkt_delay;
		end
	end
	
endprogram