`ifndef _TB_PKG_SV_
`define _TB_PKG_SV_


`include "router_pkg.sv"
import router_pkg::*;


package tb_pkg;
	import router_pkg::*;
	
	//-----------MAKE CHANGES IN THE FOLLOWING-----------
	
	
	localparam traffic_trace_file = "stim1.txt";
	localparam WARMUP_PHASE_CYCLES = 500;
	localparam MEASUREMENT_PHASE_CYCLES = 5000;
	localparam COOLDOWN_PHASE_CYCLES = 500;
	
	localparam int unsigned CLK_PRD = 1000;		//NoC clock (ps)
	localparam int unsigned GEN_CLK_PRD = 40;	//Traffic generator clock (ps)
	
	
	//-----------DO NOT MAKE CHANGES IN THE FOLLOWING-----------
	
	
	typedef struct {
		int max_x, max_y;
		int file_indx, flit_w, active_nodes, req_count;
		real mean_pkt_size, min_pkt_size, max_pkt_size, mean_period, min_prd, max_prd, mean_hop_count;
		string trfc_ptrn;
		real trfc_degree;
	} ttf_info_t;	//trace traffic file info
	
	
	typedef struct {
		int unsigned dx, dy;
		int unsigned flit_count;
		int unsigned next_pkt_delay;
		
		int unsigned pkt_id;	//set by pkt_gen
	} pkt_t;
	
	
	class packet_traces_c;
		pkt_t packet[][][];
		int unsigned packet_ctr[MAX_X][MAX_Y];
		ttf_info_t ttf_info;
		int unsigned pkt_to_send_ptr[MAX_X][MAX_Y];
		
		function new(ttf_info_t ttf_info_i);
			ttf_info = ttf_info_i;
			
			packet = new[MAX_X];
			for (int x=0; x<MAX_X; x++) begin
				packet[x] = new[MAX_Y];
				for(int y=0; y<MAX_Y; y++) begin
					packet[x][y] = new[ttf_info.req_count];
				end
			end
			
			packet_ctr = '{default:0};
			pkt_to_send_ptr = '{default:0};
		endfunction
		
		
		function bit is_active_node(int x,y);
			is_active_node = (packet_ctr[x][y] != 0);
		endfunction
		
		function void display_traffic_trace_file_info();
			$display("TRAFFIC TRACE FILE INFO: \n%p\n", ttf_info);
		endfunction
		
		
		function void push_new_packet(int unsigned sx, sy, dx, dy, pkt_size, next_pkt_delay);
			packet[sx][sy][packet_ctr[sx][sy]].dx = dx;
			packet[sx][sy][packet_ctr[sx][sy]].dy = dy;
			packet[sx][sy][packet_ctr[sx][sy]].flit_count = (pkt_size*ttf_info.flit_w) / NOC_LINK_W;
			packet[sx][sy][packet_ctr[sx][sy]].next_pkt_delay = next_pkt_delay;
			
			packet_ctr[sx][sy]++;
		endfunction
		
		function pkt_t get_pkt_to_send(int sx, sy);
			get_pkt_to_send = packet[sx][sy][pkt_to_send_ptr[sx][sy]];
			pkt_to_send_ptr[sx][sy] = (pkt_to_send_ptr[sx][sy] == packet_ctr[sx][sy]-1) ? 0 : pkt_to_send_ptr[sx][sy]+1;
		endfunction
		
		
		function void ttf_test();
			assert(ttf_info.max_x == MAX_X && ttf_info.max_y == MAX_Y) else 
				$error("Traffic trace file network size mismatch with the simulated NoC");
			
			assert(ttf_info.flit_w % NOC_LINK_W == 0) else 
				$error("FLIT_W in traffic trace file should be an integer multiple of NOC_LINK_W");
		endfunction
		
		
		function void display_traffic_trace_file();
			for(int x=0; x<MAX_X; x++) begin
				for(int y=0; y<MAX_Y; y++) begin
					
					$display("-2 %0d %0d", x, y);
					if (packet_ctr[x][y]==0) 
						$display("-99");
					
					for (int p=0; p<packet_ctr[x][y]; p++) begin
						$display("%0d %0d %0d %0d", packet[x][y][p].dx, packet[x][y][p].dy, packet[x][y][p].flit_count, packet[x][y][p].next_pkt_delay);
					end
					
				end
			end
		endfunction
	endclass
	
	
	typedef struct {
		realtime pkt_gen_time, pkt_h_tx_time, pkt_t_rx_time;
	} pkt_stats_t;
	
	
	
	class static stats_tracker_c;
		static int unsigned pkt_gen_count, flit_gen_count, pkt_rx_count, flit_rx_count;
		static int unsigned base_pkt_id[MAX_X][MAX_Y];
		static pkt_stats_t pkt_stats[MAX_X][MAX_Y][$];
		static pkt_stats_t pkt_stats_zero;
		
		static bit warmup_phase, measurement_phase, cooldown_phase;
		
		static int unsigned pkt_ctr;
		static longint total_latency_gen_to_rx, total_latency_tx_to_rx;
		static shortreal avg_pkt_latency_gen_to_rx, avg_pkt_latency_tx_to_rx;
		static real throughput_pkts_per_node, throughput_flits_per_node;
		static real injection_rate_pkts_per_node, injection_rate_flits_per_node;
		
		function new();
			pkt_stats_zero = '{default:0};
			{warmup_phase, measurement_phase, cooldown_phase} = '0;
			pkt_gen_count = 0;
			flit_gen_count = 0;
			pkt_rx_count = 0;
			flit_rx_count = 0;
		endfunction
		
		static function void log_pkt_gen_time(int sx, sy, pkt_id);
			if (measurement_phase) begin
				if (pkt_stats[sx][sy].size() == 0)
					base_pkt_id[sx][sy] = pkt_id;
					
				assert(pkt_stats[sx][sy].size() == pkt_id-base_pkt_id[sx][sy]) else $error();
				
				pkt_stats[sx][sy].push_back(pkt_stats_zero);
				pkt_stats[sx][sy][$].pkt_gen_time = $time();
			end
		endfunction
		
		static function void log_pkt_h_tx_time(int sx, sy, pkt_id);
			if (measurement_phase && pkt_stats[sx][sy].size() > pkt_id - base_pkt_id[sx][sy]) begin
				//assert(pkt_stats[sx][sy].size() >= pkt_id - base_pkt_id[sx][sy]) else $error("%d %d %d", pkt_id, base_pkt_id[sx][sy], pkt_stats[sx][sy].size());
				assert(pkt_stats[sx][sy][pkt_id-base_pkt_id[sx][sy]].pkt_h_tx_time == 0) else $error("%0d %0d %p %0d %0d", sx, sy, pkt_stats[sx][sy][pkt_id-base_pkt_id[sx][sy]], pkt_id, base_pkt_id[sx][sy]);
				pkt_stats[sx][sy][pkt_id-base_pkt_id[sx][sy]].pkt_h_tx_time = $time();
			end
		endfunction
		
		static function void log_pkt_t_rx_time(int sx, sy, pkt_id);
			if ( (measurement_phase || cooldown_phase) && pkt_id - base_pkt_id[sx][sy] < pkt_stats[sx][sy].size()) begin
				assert(pkt_stats[sx][sy][pkt_id-base_pkt_id[sx][sy]].pkt_t_rx_time == 0) else $error("%p %d %d", pkt_stats[sx][sy][pkt_id-base_pkt_id[sx][sy]], pkt_id, base_pkt_id[sx][sy]);
				pkt_stats[sx][sy][pkt_id-base_pkt_id[sx][sy]].pkt_t_rx_time = $time();
			end
		endfunction
		
		static function void log_flit_rx();
			if (measurement_phase || cooldown_phase)
				flit_rx_count++;
		endfunction
		
		static function void log_pkt_rx();
			if (measurement_phase || cooldown_phase)
				pkt_rx_count++;
		endfunction
		
		static function void log_flit_gen(int unsigned flit_count);
			if (measurement_phase || cooldown_phase)
				flit_gen_count = flit_gen_count + flit_count;
		endfunction
		
		static function void log_pkt_gen();
			if (measurement_phase || cooldown_phase)
				pkt_gen_count++;
		endfunction
		
		static function void begin_warmup_phase();
			warmup_phase = 1;
			measurement_phase = 0;
			cooldown_phase = 0;
		endfunction
		
		static function void begin_measurement_phase();
			warmup_phase = 0;
			measurement_phase = 1;
			cooldown_phase = 0;
		endfunction
		
		static function void begin_cooldown_phase();
			warmup_phase = 0;
			measurement_phase = 0;
			cooldown_phase = 1;
		endfunction
		
		static function void display_stats_summary();
			pkt_ctr = 0;
			total_latency_gen_to_rx = 0;
			total_latency_tx_to_rx = 0;
			avg_pkt_latency_gen_to_rx = 0;
			avg_pkt_latency_tx_to_rx = 0;
			
			for (int x=0; x<MAX_X; x++) begin
				for (int y=0; y<MAX_Y; y++) begin
					for (int i=0; i<pkt_stats[x][y].size(); i++) begin
						if (pkt_stats[x][y][i].pkt_t_rx_time != 0) begin
							pkt_ctr++;
							total_latency_gen_to_rx = total_latency_gen_to_rx + pkt_stats[x][y][i].pkt_t_rx_time - pkt_stats[x][y][i].pkt_gen_time;
							total_latency_tx_to_rx = total_latency_tx_to_rx + pkt_stats[x][y][i].pkt_t_rx_time - pkt_stats[x][y][i].pkt_h_tx_time;
						end
					end
				end
			end
			
			avg_pkt_latency_gen_to_rx = total_latency_gen_to_rx / pkt_ctr;
			avg_pkt_latency_tx_to_rx = total_latency_tx_to_rx / pkt_ctr;
			injection_rate_pkts_per_node  = real'(pkt_gen_count  / (MAX_X*MAX_Y) ) / (MEASUREMENT_PHASE_CYCLES + COOLDOWN_PHASE_CYCLES) * CLK_PRD/1000;
			injection_rate_flits_per_node = real'(flit_gen_count / (MAX_X*MAX_Y) ) / (MEASUREMENT_PHASE_CYCLES + COOLDOWN_PHASE_CYCLES) * CLK_PRD/1000;
			throughput_pkts_per_node = 	real'(pkt_rx_count  / (MAX_X*MAX_Y) ) / (MEASUREMENT_PHASE_CYCLES + COOLDOWN_PHASE_CYCLES) * CLK_PRD/1000;
			throughput_flits_per_node = real'(flit_rx_count / (MAX_X*MAX_Y) ) / (MEASUREMENT_PHASE_CYCLES + COOLDOWN_PHASE_CYCLES) * CLK_PRD/1000;
			
			$display("%t total_latency_gen_to_rx: %p", $time(), total_latency_gen_to_rx);
			$display("%t total_latency_tx_to_rx: %p", $time(), total_latency_tx_to_rx);
			$display("%t pkt_ctr (for latency): %p", $time(), pkt_ctr);
			$display("%t pkt_gen_count: %p", $time(), pkt_gen_count);
			$display("%t flit_gen_count: %p", $time(), flit_gen_count);
			$display("%t pkt_rx_count: %p", $time(), pkt_rx_count);
			$display("%t flit_rx_count: %p", $time(), flit_rx_count);
			$display("----------------------------------");
			$display("%t avg_pkt_latency_gen_to_rx (ps): %p", $time(), avg_pkt_latency_gen_to_rx);
			$display("%t avg_pkt_latency_tx_to_rx (ps):  %p", $time(), avg_pkt_latency_tx_to_rx);
			$display("%t injection rate (pkts/node/ns):  %f", $time(), injection_rate_pkts_per_node);
			$display("%t injection rate (flits/node/ns): %f", $time(), injection_rate_flits_per_node);
			$display("%t throughput (pkts/node/ns):  %f", $time(), throughput_pkts_per_node);
			$display("%t throughput (flits/node/ns): %f", $time(), throughput_flits_per_node);
			
			$display("\n");
			
			/* $display("%p", pkt_gen_count);
			$display("%p", flit_gen_count);
			$display("%p", pkt_rx_count);
			$display("%p", flit_rx_count);
			$display("%p", avg_pkt_latency_gen_to_rx);
			$display("%p", avg_pkt_latency_tx_to_rx);
			$display("%f", injection_rate_pkts_per_node);
			$display("%f", injection_rate_flits_per_node);
			$display("%f", throughput_pkts_per_node);
			$display("%f", throughput_flits_per_node); */
			
		endfunction
		
		static function void display_stats_detailed();
			for (int i=0; i<pkt_stats[0][0].size(); i++) 
				$display("%p", pkt_stats[0][0][i]);
		endfunction
	endclass
	
	
	
	function dir_t get_next_route_for_tx(int sx, sy, dx, dy);
			assert (!(sx==dx && sy==dy)) else $error("Destination(%0d,%0d) same as source",dx, dy);
			
			if (dx > sx)
				get_next_route_for_tx = E;
			else if (dx < sx)
				get_next_route_for_tx = W;
			else if (dy > sy)
				get_next_route_for_tx = S;
			else if (dy < sy)
				get_next_route_for_tx = N;
			else
				$error("NRC at tx");
		endfunction
	
endpackage

`endif
