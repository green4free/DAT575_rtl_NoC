function generate_stim_files()
	%-----------MAKE CHANGES IN THE FOLLOWING-----------%
	MAX_X = 8;						% Number of columns
	MAX_Y = 8;						% Number of rows
	ACTIVE_NODES = MAX_X * MAX_Y;	% Number of active nodes that can inject traffic in the NoC. If fewer than MAX_X*MAX_Y, then active nodes are sleected randomly
	PKTS_PER_SRC = 3000; 			% packets per active master node
	TRAFFIC_PTRN = 'transpose';	% traffic pattern
	TRAFFIC_PTRN_DEGREE = 1;
	AVG_PKT_PRD = [100];			% following is for an XxY NoC
	
	STIM_FILE_COUNT = 1;    		% number of stimulus files to be generated, in case AVG_PKT_PRD is a vector
	initial_file_id = 0;			% the file name stim{file_id}.txt. file_id starts from initial_file_id
	
	
	%-----------DO NOT MAKE CHANGES IN THE FOLLOWING-----------%
	FLIT_W = 128;					% Flit width defines the size of each flit of a packet
	MIN_PKT_SIZE = 3;				% Flits per packet
	MAX_PKT_SIZE = 3;				% Flits per packet
	MIN_PKT_PRD = 50;				% GEN_CLK_PRD cycles (defined in tb_pkg.sv)
	MAX_PKT_PRD = AVG_PKT_PRD*2 - MIN_PKT_PRD;
    
	
	COMM_PROTOCOL = 'min_max_pkt_size';	% min_max_pkt_size: generate pkts of MIN_PKT_SIZE and MAX_PKT_SIZE flits only
										% req_resp: It only works if the simulation platform supports it.
										% - generates pkts of 1 and 5 flits. With FLIT_W=128 we get 128b read_req and 640b write_req traffic.
										% - Each read_req and write_req generates a 60b and 128b read_resp and write_resp, respectively, in the testbench.
										% - Ignores PKT_SIZE, doubles PKT_PRD and halves PKTS_PER_SRC in stimulus.
	
	
	for i = 1 : STIM_FILE_COUNT
		tic;
		
		stimulus(MAX_X, MAX_Y, FLIT_W, ACTIVE_NODES, PKTS_PER_SRC, MIN_PKT_SIZE, MAX_PKT_SIZE, MIN_PKT_PRD, MAX_PKT_PRD(i), TRAFFIC_PTRN, COMM_PROTOCOL, TRAFFIC_PTRN_DEGREE, initial_file_id+i-1);
		
		toc
		
		disp(newline);
	end
	
end
%{
Traffic patterns:
- one_to_all:			An active node is specified in stimulus.m file. One packet is generated by the active node to all of the remaining nodes in the network.
- hs_parsec:			Parsec based Hotspot traffic pattern. Hotspot nodes are specified in stimulus.m file. The TRAFFIC_PTRN_DEGREE is the ratio of traffic going to the hotspot nodes over the total traffic generated by a node. 1-flit-pkts->70%. 5-flit-pkts->30%.
- hotspots_center_x4:	Center four nodes are hotspot nodes. The TRAFFIC_PTRN_DEGREE is the ratio of traffic going to the hotspot nodes over the total traffic generated by a node.
- hotspots_corner_x4:	Corner four nodes are hotspot nodes. The TRAFFIC_PTRN_DEGREE is the ratio of traffic going to the hotspot nodes over the total traffic generated by a node.
- hotspots_center_x1:	Center one node is the hotspot node. The TRAFFIC_PTRN_DEGREE is the ratio of traffic going to the hotspot nodes over the total traffic generated by a node.
- hotspots_corner_x1:	Corner one node is the hotspot node. The TRAFFIC_PTRN_DEGREE is the ratio of traffic going to the hotspot nodes over the total traffic generated by a node.
- uniform_rand:			Packets are sent to a uniformly random distribution of destination nodes
- neighbour:			Each node sends packets only to its neighbouring nodes, with a maximum hop-count specified by TRAFFIC_PTRN_DEGREE. Also, neighbour_traffic_ratio in stimulus.m
- tornado:				[dx,dy]=[mod(sx+degree,max_x), mod(sy+degree,max_y)]. traffic_ptrn_degree specifies tornado traffic hop-count. set tornado_direction_x and tornado_direction_y in stimulus.m specify the direction of tornado traffic
- converge:				Traffic by all nodes in a row/column converges to a hotspot node in that row/column. The nodes on which traffic converges do not generate any traffic. set converge_direction_x or converge_direction_y in stimulus to 
- 
%}