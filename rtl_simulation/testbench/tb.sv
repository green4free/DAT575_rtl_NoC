`include "router_pkg.sv"
`include "tb_pkg.sv"

import router_pkg::*;
import tb_pkg::*;

`timescale 1ps/1ps


module tb();
	packet_traces_c pkt_traces_all;
	stats_tracker_c pkt_stats_tracker;
	
	logic clk 	 = 1'b0;
	logic arst_n = 1'b1;
	
	//pkt_gen
	pkt_t pkt_to_queue[MAX_X][MAX_Y];
	logic pkt_rdy_to_queue[MAX_X][MAX_Y];
	
	//pkt_queue
	pkt_t pkt_to_tx[MAX_X][MAX_Y];
	logic pkt_to_tx_valid[MAX_X][MAX_Y];
	
	//TX
	logic tx_ready_to_queue[MAX_X][MAX_Y];
	channel_t flit_to_noc[MAX_X][MAX_Y];
	logic credits_from_noc[MAX_X][MAX_Y][NUM_VCS];
	
	//NoC
	channel_t flit_from_noc[MAX_X][MAX_Y];
	
	//RX
	logic credits_to_noc[MAX_X][MAX_Y][NUM_VCS];
	
	
	initial begin
		#(CLK_PRD/2);
		forever begin
			#(CLK_PRD/2) clk = 1;
			#(CLK_PRD/2) clk = 0;
		end
	end
	
	
	initial begin
		// Initialize environment
		$timeformat(-9, 3, " ns:", 0);
		
		read_traffic_trace_file(pkt_traces_all);
		reset_noc(1);
		
		pkt_stats_tracker.begin_warmup_phase();
		repeat(WARMUP_PHASE_CYCLES) @(posedge clk);
		
		pkt_stats_tracker.begin_measurement_phase();
		repeat(MEASUREMENT_PHASE_CYCLES) @(posedge clk);
		
		pkt_stats_tracker.begin_cooldown_phase();
		repeat(COOLDOWN_PHASE_CYCLES) @(posedge clk);
		
		pkt_stats_tracker.display_stats_summary();
		//pkt_stats_tracker.display_stats_detailed();
		$stop();
	end
	
	
	genvar xid,yid;
	for (xid=0; xid<MAX_X; xid++) begin : GEN_X
		for(yid=0; yid<MAX_Y; yid++) begin : GEN_Y
			
			pkt_gen #(xid, yid, xid*MAX_Y+yid, 1)
				pkt_gen_i (
				.clk(clk),
				.arst_n(arst_n),
				.pkt_stats_tracker(pkt_stats_tracker),
				.pkt_traces_all(pkt_traces_all),
				.pkt_to_queue(pkt_to_queue[xid][yid]),
				.pkt_rdy_to_queue(pkt_rdy_to_queue[xid][yid])
			);
			
			pkt_queue #(xid, yid)
				pkt_q_i (
				.clk(clk),
				.arst_n(arst_n),
				.pkt_to_queue(pkt_to_queue[xid][yid]),
				.pkt_rdy_to_queue(pkt_rdy_to_queue[xid][yid]),
				
				.tx_ready(tx_ready_to_queue[xid][yid]),
				.pkt_to_tx(pkt_to_tx[xid][yid]),
				.pkt_to_tx_valid(pkt_to_tx_valid[xid][yid])
			);
			
			pkt_tx #(xid, yid)
				pkt_tx_i (
				.clk(clk),
				.arst_n(arst_n),
				.pkt_stats_tracker(pkt_stats_tracker),
				.tx_ready(tx_ready_to_queue[xid][yid]),
				.pkt_to_tx(pkt_to_tx[xid][yid]),
				.pkt_to_tx_valid(pkt_to_tx_valid[xid][yid]),
				
				.flit_to_noc(flit_to_noc[xid][yid]),
				.credits_from_noc(credits_from_noc[xid][yid])
			);
			
			pkt_rx #(xid, yid)
				pkt_rx_i (
				.clk(clk),
				.arst_n(arst_n),
				.pkt_stats_tracker(pkt_stats_tracker),
				
				.flit_from_noc(flit_from_noc[xid][yid]),
				.credits_to_noc(credits_to_noc[xid][yid])
			);
		end
	end
	
	
	noc2d_vc noc2d_vc_i 
	(
		.clk(clk),
		.arst_n(arst_n),
		.inport(flit_to_noc),
		.outcredit(credits_from_noc),
		.outport(flit_from_noc),
		.incredit(credits_to_noc)
	);
	
	
	function automatic void read_traffic_trace_file(ref packet_traces_c pkt_traces_all);
		ttf_info_t ttf_info;
		int file_h; //File handler
		string line;
		
		int out_i;
		int val[4];
		int unsigned sx, sy;
		int unsigned dx, dy;
		int unsigned pkt_size, next_pkt_delay;
		
		$display("INFO: READING TRAFFIC TRACE FILE.");
		
		 // Open the CSV file for reading
		file_h = $fopen(traffic_trace_file, "r");
		assert (file_h != 0) else $error("UNABLE TO OPEN TRAFFIC TRACE FILE %s", traffic_trace_file);
		
		// Read the first line
        line = "";
        out_i=$fgets(line, file_h);
		// Parse the first line
		out_i=$sscanf(line, "%d %d %d %d %d %d %f %d %d %f %d %d %s %f %f %d", ttf_info.file_indx, ttf_info.max_x, ttf_info.max_y, ttf_info.flit_w, ttf_info.active_nodes, ttf_info.req_count, ttf_info.mean_pkt_size, ttf_info.min_pkt_size, ttf_info.max_pkt_size, ttf_info.mean_period, ttf_info.min_prd, ttf_info.max_prd, ttf_info.trfc_ptrn, ttf_info.trfc_degree, ttf_info.mean_hop_count, ttf_info.file_indx);
		
		
		pkt_traces_all = new(ttf_info);
		pkt_traces_all.ttf_test();
		pkt_traces_all.display_traffic_trace_file_info();
		
		 while (!$feof(file_h)) begin
			line = "";
			out_i=$fgets(line, file_h);
			out_i=$sscanf(line, "%d %d %d %d", val[0], val[1], val[2], val[3]);
			
			if (val[0] == -2) begin
				{sx, sy} = {val[1], val[2]};
			end else if (val[0] == -99) begin	//No traffic for this node
				//do nothing
			end else if (val[0] == -100) begin	//end of file
				//do nothing
			end else begin
				{dx, dy, pkt_size, next_pkt_delay} = {val[0], val[1], val[2], val[3]};
				pkt_traces_all.push_new_packet(sx, sy, dx, dy, pkt_size, next_pkt_delay);
			end
        end

        // Close the file
        $fclose(file_h);
		$display("INFO: TRAFFIC TRACE FILE READ COMPLETE.");
		//pkt_traces_all.display_traffic_trace_file();
	endfunction
	
	
	task reset_noc(input logic initial_value);
		arst_n = initial_value;
		
		repeat (2) @(posedge clk);
		#200ps;
		arst_n = 0;
		
		repeat (5) @(posedge clk);
		#200ps;
		arst_n = 1;
	endtask
endmodule
