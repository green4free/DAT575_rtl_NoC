function success = stimulus(max_x, max_y, flit_w, active_nodes, req_count, min_pkt_size, max_pkt_size, min_prd, max_prd, trfc_ptrn, comm_protocol, degree, file_id)
	
	plot_sample_distributions = 0;  %for (masters<max), it will only plot if plotted master is selected for traffic generation
	success = 0;
	
	
	if active_nodes > max_x*max_y
		error('ERROR: ACTIVE_NODES GREATER THAN AVAILABLE NODES');
	end
	if active_nodes ~= max_x*max_y
		disp('WARNING: ACTIVE_NODES ~= NETWORK SIZE');
	end
	
	stim_file_location = pwd;
	temp_file_location = pwd;
	
	if ispc
		disp('Running on Windows');
		stim_file_location = [stim_file_location '\stim' int2str(file_id) '.txt'];
		temp_file_location = [temp_file_location '\matlab_temp'];
	elseif isunix && ~ismac
		disp('Running on Linux');
		stim_file_location = [stim_file_location '/stim' int2str(file_id) '.txt'];
		temp_file_location = [temp_file_location '/matlab_temp'];
	else
		disp('Unsupported operating system');
	end
	
	
	x_bits = ceil(log2(max_x));
	y_bits = ceil(log2(max_y));
	
	
	%Open a temporary file for writing to it the traffic pattern
	temp_fid = fopen(temp_file_location, 'w');
	if temp_fid == -1
		error('Error opening temp_fid.');
	end
	
	
	
	if(strcmp(comm_protocol, 'req_resp'))
		disp('INFO: REQUEST_RESPONSE TRAFFIC PATTREN SELECTED. IT DOUBLES PKT_PRD AT SOURCE NODE AND DIVIDES PKT_COUNT AT SOURCE BY 2. (MIN_PKT_SIZE, MAX_PKT_SIZE) CHANGED TO (1, 5)');
		req_count = req_count/2;
		min_pkt_size = 1;  %code is specific to 1
		max_pkt_size = 5;  %code is specific to 5
		min_prd = min_prd * 2;
		max_prd = max_prd * 2;
	end
	
	
	if strcmp(trfc_ptrn,'one_to_all')
		src_x = 0;
		src_y = 0;
		req_count = max_x * max_y - 1;
		selected_masters = src_x*max_y+src_y;
		fprintf('INFO: ONLY ONE MASTER NODE(%d,%d) SELECTED.\n', src_x, src_y);
	elseif active_nodes == 1
		src_x = 0;
		src_y = 0;
		req_count = max_x * max_y - 1;
		selected_masters = src_x*max_y+src_y;
		fprintf('INFO: ONLY ONE MASTER NODE(%d,%d) SELECTED.\n', src_x, src_y);
	elseif active_nodes < max_x*max_y
		selected_masters = randsample(max_x*max_y, active_nodes)' -1;
		fprintf('INFO: SELECTED MASTER NODES ARE (')
		fprintf('%d ', selected_masters);
		fprintf(')\n');
	else
		selected_masters = 	0 : max_x*max_y-1;
	end
	
	
	mean_period = [];
	mean_pkt_size = [];
	mean_hop_count = [];
	
	
	for src_x = 0 : max_x-1
		for src_y = 0 : max_y-1
			fprintf(temp_fid, '-2 %d %d \n', src_x, src_y);
			
			if ( any(src_x*max_y + src_y == selected_masters) )
				curr_node_id = src_x*max_y + src_y;
				
				switch trfc_ptrn
				case 'hs_parsec'
					hs_node_ids = [0, 7, 9, 14, 18, 21, 27, 28, 35, 36, 42, 45, 49, 54, 56, 63];	%selected hotspot nodes
					hs_node_ids = hs_node_ids(hs_node_ids < (max_x*max_y))	%remove node indices higher than NoC size
					
					if (curr_node_id==0)
						if (max_x*max_y>64)
							error("HS_NODES ONLY SPECIFIED UPTILL A 8X8 2D MESH NOC.");
						end
						
						fprintf('INFO: SETTING HOTSPOT NODE INDICES TO ');
						fprintf('%d ', hs_node_ids);
						fprintf('\n');
					end
					
					hs_node_ids(hs_node_ids == curr_node_id) = [];	%if curr_node_id exists in hs_node_ids vector, remove it
					hs_node_ids = [hs_node_ids(hs_node_ids < curr_node_id) hs_node_ids(hs_node_ids > curr_node_id)-1];
					hs_nodes_count = length(hs_node_ids);
					non_hs_nodes_count = max_x*max_y-hs_nodes_count-1;
					
					if (degree < 1)
						hs_node_weight = non_hs_nodes_count * degree / (hs_nodes_count * (1-degree));
						dst_nodes_weights = ones(1, max_x*max_y-1);
					else % degree==1
						hs_node_weight = 1;
						dst_nodes_weights = zeros(1, max_x*max_y-1);
					end
					dst_nodes_weights(hs_node_ids+1) = hs_node_weight;
					
					dst_node_ids = randsample([0:curr_node_id-1 curr_node_id+1:max_x*max_y-1], req_count, true, dst_nodes_weights); %randsample(population, k, replacement, weight)
				case 'one_to_all'
					dst_node_ids = 0:(max_x*max_y-1);
					dst_node_ids(dst_node_ids==curr_node_id) = [];
				case 'hotspots_center_x4'  %four hotspots
					if ((max_x==2 && max_y==2) || (max_x==2 && max_y==3) || (max_x==3 && max_y==3))
						error('ERROR: HOTSPOT_CENTER_X4 TRAFFIC CANNOT BE GENERATED FOR 2X2, 2X3, 3X3 NETWORKS');
					end
					if (degree>1)
						error('ERROR: IN HOTSPOT TRAFFIC, FOR A NODE, THE DEGREE IS THE RATIO OF TRAFFIC GOING TO HOTSPOTS TO TRAFFIC A NODE GENERATES. DEGREE SHOULD BE <= 1.');
					end
					
					%specify the top-left hotspot node using mx_by2 and my_by2
					mx_by2 = fix(max_x/2) -1;
					my_by2 = fix(max_y/2) -1;
					
					hs_node_ids = [mx_by2*max_y+my_by2 mx_by2*max_y+(my_by2+1) (mx_by2+1)*max_y+my_by2 (mx_by2+1)*max_y+(my_by2+1)];
					hs_node_ids(hs_node_ids == curr_node_id) = [];  %if curr_node_id is also a hotspot node, remove it
					hs_node_ids = [hs_node_ids(hs_node_ids < curr_node_id) hs_node_ids(hs_node_ids > curr_node_id)-1];	%if hs_node_ids > curr_node_id, subtract 1 from hs_node_ids. because weights are indexed from 1 to max_x*max_y-1
					hs_nodes_count = length(hs_node_ids);
					non_hs_nodes_count = max_x*max_y-hs_nodes_count-1;
					
					if (degree < 1)
						hs_node_weight = non_hs_nodes_count * degree / (hs_nodes_count * (1-degree));
						dst_nodes_weights = ones(1, max_x*max_y-1);
					else % degree==1
						hs_node_weight = 1;
						dst_nodes_weights = zeros(1, max_x*max_y-1);
					end
					dst_nodes_weights(hs_node_ids+1) = hs_node_weight;
					
					dst_node_ids = randsample([0:curr_node_id-1 curr_node_id+1:max_x*max_y-1], req_count, true, dst_nodes_weights); %randsample(population, k, replacement, weight)
				case 'hotspots_corner_x4'
					if (max_x==2 && max_y==2)
						error('ERROR: HOTSPOT_CORNER_X4 TRAFFIC CANNOT BE GENERATED FOR 2X2 NETWORKS');
					end
					if (degree>1)
						error('ERROR: IN HOTSPOT TRAFFIC, FOR A NODE, THE DEGREE IS THE RATIO OF TRAFFIC GOING TO HOTSPOTS TO TRAFFIC A NODE GENERATES. DEGREE SHOULD BE <= 1.');
					end
					
					hs_node_ids = [0 max_y-1 (max_x-1)*max_y max_x*max_y-1];
					hs_node_ids(hs_node_ids == curr_node_id) = []  %if curr_node_id is also a hotspot node, remove it
					hs_node_ids = [hs_node_ids(hs_node_ids < curr_node_id) hs_node_ids(hs_node_ids > curr_node_id)-1];	%if hs_node_ids > curr_node_id, subtract 1 from hs_node_ids. because weights are indexed from 1 to max_x*max_y-1
					hs_nodes_count = length(hs_node_ids);
					non_hs_nodes_count = max_x*max_y-hs_nodes_count-1;
					
					if (degree < 1)
						hs_node_weight = non_hs_nodes_count * degree / (hs_nodes_count * (1-degree));
						dst_nodes_weights = ones(1, max_x*max_y-1);
					else % degree==1
						hs_node_weight = 1;
						dst_nodes_weights = zeros(1, max_x*max_y-1);
					end
					dst_nodes_weights(hs_node_ids+1) = hs_node_weight;
					
					dst_node_ids = randsample([0:curr_node_id-1 curr_node_id+1:max_x*max_y-1], req_count, true, dst_nodes_weights); %randsample(population, k, replacement, weight)
				case 'hotspots_center_x1'
					%specify the top-left hotspot node using mx_by2 and my_by2
					mx_by2 = fix(max_x/2);
					my_by2 = fix(max_y/2);
					
					if (max_x==2 && max_y==2)
						error('ERROR: HOTSPOT_CENTER_X1 TRAFFIC CANNOT BE GENERATED FOR 2X2 NETWORKS');
					end
					if (degree>1)
						error('ERROR: IN HOTSPOT TRAFFIC, FOR A NODE, THE DEGREE IS THE RATIO OF TRAFFIC GOING TO HOTSPOTS TO TRAFFIC A NODE GENERATES. DEGREE SHOULD BE <= 1.');
					end
					
					hs_node_ids = mx_by2*max_y + my_by2;
					if (hs_node_ids == curr_node_id)
						hs_node_ids = hs_node_ids + 1;
					end
					hs_node_ids = [hs_node_ids(hs_node_ids < curr_node_id) hs_node_ids(hs_node_ids > curr_node_id)-1];	%if hs_node_ids > curr_node_id, subtract 1 from hs_node_ids. because weights are indexed from 1 to max_x*max_y-1
					hs_nodes_count = length(hs_node_ids);
					non_hs_nodes_count = max_x*max_y-hs_nodes_count-1;
					
					if (degree < 1)
						hs_node_weight = non_hs_nodes_count * degree / (hs_nodes_count * (1-degree));
						dst_nodes_weights = ones(1, max_x*max_y-1);
					else % degree==1
						hs_node_weight = 1;
						dst_nodes_weights = zeros(1, max_x*max_y-1);
					end
					dst_nodes_weights(hs_node_ids+1) = hs_node_weight;
					
					dst_node_ids = randsample([0:curr_node_id-1 curr_node_id+1:max_x*max_y-1], req_count, true, dst_nodes_weights);
				case 'hotspots_corner_x1'
					hs_node_ids = 0;
					
					if degree>1
						error('ERROR: IN HOTSPOT TRAFFIC, FOR A NODE, THE DEGREE IS THE RATIO OF TRAFFIC GOING TO HOTSPOTS TO TRAFFIC A NODE GENERATES. DEGREE SHOULD BE <= 1.');
					end
					
					if (hs_node_ids == curr_node_id)
						hs_node_ids = max_x*max_y -1;
					end
					hs_node_ids = [hs_node_ids(hs_node_ids < curr_node_id) hs_node_ids(hs_node_ids > curr_node_id)-1];	%if hs_node_ids > curr_node_id, subtract 1 from hs_node_ids. because weights are indexed from 1 to max_x*max_y-1
					hs_nodes_count = length(hs_node_ids);
					non_hs_nodes_count = max_x*max_y-hs_nodes_count-1;
					
					if (degree < 1)
						hs_node_weight = non_hs_nodes_count * degree / (hs_nodes_count * (1-degree));
						dst_nodes_weights = ones(1, max_x*max_y-1);
					else % degree==1
						hs_node_weight = 1;
						dst_nodes_weights = zeros(1, max_x*max_y-1);
					end
					dst_nodes_weights(hs_node_ids+1) = hs_node_weight;
					
					dst_node_ids = randsample([0:curr_node_id-1 curr_node_id+1:max_x*max_y-1], req_count, true, dst_nodes_weights);
				case 'uniform_rand'   %uneffected by degree
					dst_node_ids = randsample([0:curr_node_id-1 curr_node_id+1:max_x*max_y-1], req_count, true);
				case 'neighbour'  %degree is the maximum hop count a DST can be from SRC
					neighbour_traffic_ratio = 1; %Ratio of neighbour traffic to total traffic
					
					if degree<1 || (degree ~= fix(degree)) || neighbour_traffic_ratio<0 || neighbour_traffic_ratio>1
						error("IN NEIGHBOUT TRAFFIC PATTERN, DEGREE SPECIFIES THE MAXIMUM HOP COUNT FROM A NODE TO ANY NODE IT CAN SEND A PACKET TO. IT SHOULD BE AN INTEGER GREATER THAN 0. 0<=NEIGHBOUR_TRAFFIC_RATION<=1");
					end
					
					hs_node_ids = centralized_tp(max_x, max_y, src_x, src_y, degree);
					
					hs_node_ids(hs_node_ids == curr_node_id) = [];  %if curr_node_id is also a hotspot node, remove it
					hs_node_ids = [hs_node_ids(hs_node_ids < curr_node_id) hs_node_ids(hs_node_ids > curr_node_id)-1];	%if hs_node_ids > curr_node_id, subtract 1 from hs_node_ids. because weights are indexed from 1 to max_x*max_y-1
					hs_nodes_count = length(hs_node_ids);
					non_hs_nodes_count = max_x*max_y-hs_nodes_count-1;
					
					if (neighbour_traffic_ratio < 1)
						hs_node_weight = non_hs_nodes_count * neighbour_traffic_ratio / (hs_nodes_count * (1-neighbour_traffic_ratio));
						dst_nodes_weights = ones(1, max_x*max_y-1);
					else % neighbour_traffic_ratio==1
						hs_node_weight = 1;
						dst_nodes_weights = zeros(1, max_x*max_y-1);
					end
					dst_nodes_weights(hs_node_ids+1) = hs_node_weight;
					
					dst_node_ids = randsample([0:curr_node_id-1 curr_node_id+1:max_x*max_y-1], req_count, true, dst_nodes_weights);
				case 'tornado' %degree specifies tornado traffic hop-count
					%set following variables to generate tornado traffic in x or y or both directions
					tornado_direction_x = 1;
					tornado_direction_y = 0;
					
					if (degree <= 0 || degree ~= fix(degree))
						error('ERROR: INCORRECT TRAFFIC_PTRN_DEGREE FOR TORNADO TRAFFIC.');
					end
					if ((tornado_direction_x && degree>=max_x) || (tornado_direction_y && degree>=max_y))
						error('ERROR: INCORRECT TRAFFIC_PTRN_DEGREE OUT OF RANGE FOR TORNADO TRAFFIC.');
					end
					
					dst_node = mod(src_x + tornado_direction_x*degree, max_x)*max_y + mod(src_y + tornado_direction_y*degree, max_y);
					dst_node_ids = ones(1, req_count) .* dst_node;
				case 'converge' %traffic by all nodes in a row/column converges to a hotspot node in that row/column
					%The nodes on which traffic converges do not generate any traffic
					%set following variables to generate converge traffic in either x or y directions only
					converge_direction_x = 1;
					converge_direction_y = 0;
					
					if (degree < 0 || fix(degree) ~= degree)
						error('ERROR: INCORRECT TRAFFIC_PTRN_DEGREE FOR CONVERGE TRAFFIC');
					end
					
					if (curr_node_id == 0)
						fprintf(1, 'INFO: NODES ON THE ROW/COLUMN ON WHICH TRAFFIC CONVERGES, WILL NOT GENERATE ANY TRAFFIC.\n');
						fprintf(1, 'INFO: THESE NODES WILL BE REMOVED FROM MASTER COUNT\n');
					end
					
					if (converge_direction_x)
						if (degree >= max_x)
							error('ERROR: TRAFFIC_PTRN_DEGREE FOR CONVERGE TRAFFIC OUT OF RANGE\n');
						end
						d_x = degree;
						d_y = src_y;
					elseif (converge_direction_y)
						if (degree >= max_y)
							error('ERROR: TRAFFIC_PTRN_DEGREE FOR CONVERGE TRAFFIC OUT OF RANGE\n');
						end
						d_x = src_x;
						d_y = degree;
					else
						error('ERROR: INCORRECT SETTINGS IN STIMULUS.M FILE\n');
					end
					
					dst_node = d_x * max_y + d_y;
					if (dst_node_ids ~= curr_node_id)
						dst_node_ids = ones(1, req_count) .* dst_node;
					else 
						selected_masters(selected_masters == curr_node_id) = [];
						active_nodes = active_nodes - 1;
						fprintf(temp_fid, '-99 \n');
						continue;
					end
				case 'bit_complement'   %uneffected by degree
					if (max_x ~= max_y || rem(log2(max_x),1) ~= 0)
						error('ERROR: BIT_COMPLEMENT TRAFFIC CAN ONLY BE GENERATED FOR 2^n X 2^n SQUARE MESH NETWORKS.\n');
					end
					bit_comp_mask = max_x - 1;
					dst_node = bitxor(src_x, bit_comp_mask) * max_y + bitxor(src_y, bit_comp_mask);
					dst_node_ids = ones(1, req_count) .* dst_node;
				case 'transpose'   %uneffected by degree
					if (max_x ~= max_y)
						error('ERROR: TRANSPOSE TRAFFIC CAN ONLY BE GENERATED FOR SQUARE 2D MESH NETWORKS.\n');
					end
					 if (curr_node_id == 0)
						fprintf(1, 'INFO: NODES ON THE DIAGONAL WILL NOT GENERATE ANY TRAFFIC.\n');
						fprintf(1, 'INFO: THESE NODES WILL BE REMOVED FROM MASTER COUNT\n');
					 end
					dst_node = ((src_y * max_x) + src_x);
					if (curr_node_id == dst_node)
						selected_masters(selected_masters == curr_node_id) = [];
						active_nodes = active_nodes - 1;
						fprintf(temp_fid, '-99 \n');
						continue;
					end
					dst_node_ids = ones(1, req_count) .* dst_node;
				case 'bit_reverse'	%uneffected by degree
					if (max_x ~= max_y || rem(log2(max_x),1) ~= 0)
						error('ERROR: BIT_REVERSE TRAFFIC CAN ONLY BE GENERATED FOR 2^n X 2^n SQUARE MESH NETWORKS.\n');
					end
					if (curr_node_id == 0)
						fprintf(1, 'INFO: NODES WITH BINARY PALINDROMIC IDS WILL NOT GENERATE ANY TRAFFIC.\n');
						fprintf(1, 'INFO: THESE NODES WILL BE REMOVED FROM MASTER COUNT.\n');
					end
					
					d_x = bin2dec( circshift( dec2bin(src_x, x_bits), degree) );
					d_y = bin2dec( circshift( dec2bin(src_y, y_bits), degree) );
					dst_node = d_x*max_y + d_y;
					
					reverse_bit_vector = bitrevorder(0:max_x^2-1);
					dst_node = reverse_bit_vector(curr_node_id+1);
					
					if(curr_node_id == dst_node)
						selected_masters(selected_masters == curr_node_id) = [];
						active_nodes = active_nodes - 1;
						fprintf(temp_fid, '-99 \n');
						continue;
					end
					dst_node_ids = ones(1, req_count) .* dst_node;
				case {'bit_rotation','bit_shuffle'} %bit_rotation: degree>0 -> right rotate. bit_shuffle: degree<0 -> left rotate.
					if (max_x ~= max_y || rem(log2(max_x),1) ~= 0)
						error('ERROR: THIS TRAFFIC CAN ONLY BE GENERATED FOR 2^n X 2^n SQUARE 2D-MESH NETWORKS.\n');
					end
					if (degree==0 || abs(degree)>=x_bits || abs(degree)>=y_bits)
						error('ERROR: DEGREE OUT OF RANGE.')
					end
					if (trfc_ptrn=='bit_rotation' && degree<0)
						error('ERROR: FOR BIT_ROTATION TRAFFIC PATTERN, TRAFFIC_PTRN_DEGREE > 0.')
					elseif (trfc_ptrn=='bit_shuffle' && degree>0)
						error('ERROR: FOR BIT_SHUFFLE TRAFFIC PATTERN, TRAFFIC_PTRN_DEGREE > 0.')
					end
					
					if (curr_node_id == 0)
						fprintf(1, 'INFO: NODES {(0,0), (max_x-1,0), (0,max_y-1), (max_x-1,max_y-1)} WILL NOT GENERATE ANY TRAFFIC.\n');
						fprintf(1, 'INFO: THESE NODES WILL BE REMOVED FROM MASTER COUNT.\n');
					end
					
					d_x = bin2dec( circshift( dec2bin(src_x, x_bits), degree) );
					d_y = bin2dec( circshift( dec2bin(src_y, y_bits), degree) );
					dst_node = d_x*max_y + d_y;
					
					if(curr_node_id == dst_node)
						selected_masters(selected_masters == curr_node_id) = [];
						active_nodes = active_nodes - 1;
						fprintf(temp_fid, '-99 \n');
						continue;
					end
					dst_node_ids = ones(1, req_count) .* dst_node;
				end	%end of Switch
				
				
				dst_x = fix(dst_node_ids/max_y);
				dst_y = rem(dst_node_ids,max_y);
				
				if(strcmp(trfc_ptrn,'one_to_all'))
					if(strcmp(comm_protocol, 'req_resp'))
						error('ERROR: ONE_TO_ALL NOT SETUP FOR REQ_RESP\n');
					elseif (strcmp(comm_protocol, 'min_max_pkt_size'))
						pkt_sizes = ((unidrnd(2, [1, req_count])-1)*(max_pkt_size-min_pkt_size))+min_pkt_size;
					else
						pkt_sizes = ones(1, req_count) .* 2;
					end
					period = ones(1, req_count) .* (min_prd + 20);
				else
					if(strcmp(comm_protocol, 'req_resp'))
						pkt_sizes = (unidrnd(2, [1, req_count])-1)*4+1; %pkts of 1 or 5 flits
					elseif (strcmp(comm_protocol, 'min_max_pkt_size'))
						if(strcmp(trfc_ptrn, 'hs_parsec'))
							pkt_sizes = randsample([1,5], req_count, true, [0.7,0.3]);
						else
							pkt_sizes = ((unidrnd(2, [1, req_count])-1)*(max_pkt_size-min_pkt_size))+min_pkt_size;
						end
					else
						pkt_sizes = poissrnd((min_pkt_size+max_pkt_size)/2-min_pkt_size, 1, req_count) + min_pkt_size;
					end
					%period = poissrnd((max_prd+min_prd)/2-min_prd, 1, req_count) + min_prd;
					%period = unidrnd(max_prd-min_prd+1, [1,req_count]) + min_prd - 1;
					%period = ceil( ((max_prd+min_prd)/2/80).*randn(1,req_count) + (max_prd+min_prd)/2 );
					period = ceil( betarnd(10,10, 1,req_count) .* (max_prd-min_prd) + min_prd );
				end
				
				
				for pkt_id = 1 : req_count
					fprintf(temp_fid, '%d %d %d %d\n', dst_x(pkt_id), dst_y(pkt_id), pkt_sizes(pkt_id), period(pkt_id));
				end
				
				mean_period = [mean_period period];
				mean_pkt_size = [mean_pkt_size pkt_sizes];
				mean_hop_count = [mean_hop_count (abs(src_x-dst_x)+abs(src_y-dst_y))];
				
				if (src_x==3 && src_y==3 && plot_sample_distributions == 1)
					plot_pd();
				end
				
			else %end if
				fprintf(temp_fid, '-99 \n');
			end
		end %end for loop Y
	end	%end for loop X
	fprintf(temp_fid, '-100');
	fclose(temp_fid);
	
	
	mean_pkt_size = mean(mean_pkt_size);
	mean_period = mean(mean_period);
	mean_hop_count =  mean(mean_hop_count);
	
	if(strcmp(comm_protocol, 'req_resp'))
		req_count = req_count * 2;
	end
	
	
	% Copy temporary file to stimulus file.
	stim_fid = fopen(stim_file_location, 'w');
	fprintf(stim_fid, '-1 %d %d %d %d %d %6.6f %d %d %6.6f %d %d %s %f %6.6f %d\n',max_x, max_y, flit_w, active_nodes, req_count, mean_pkt_size, min_pkt_size, max_pkt_size, mean_period, min_prd, max_prd, trfc_ptrn, degree, mean_hop_count, file_id);
	fclose(stim_fid);
	
	stim_fid = fopen(stim_file_location, 'a');
	temp_fid = fopen(temp_file_location, 'r');
	
	if stim_fid == -1 || temp_fid == -1
		error('Error opening stim_fid || temp_fid.');
	end
	
	fileContents = fread(temp_fid, '*char')';
	fwrite(stim_fid, fileContents, 'char');
	
	fclose(temp_fid);
	fclose(stim_fid);
	
	delete(temp_file_location);
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
	
	function plot_pd()
		
		destinations_i = [dst_node_ids(dst_node_ids<(src_x*max_y+src_y)) dst_node_ids(dst_node_ids>=(src_x*max_y+src_y))+1];
		figure;
		xRange = 0:1:max_x*max_y-1;   %# Range of integers to compute a probability for
		N = hist(dst_node_ids,xRange);	  %# Bin the data
		N = N./numel(dst_node_ids);
		stem(xRange,N);					 %# Plot the probabilities for each integer
		title('2D DESTINATION PROBABILITY DISTRIBUTION FOR A NODE');
		xlabel('Nodes');
		ylabel('Probability');
		
		figure;
		xRange=zeros(1,max_x*max_y);
		yRange=zeros(1,max_x*max_y);
		node_pd=[];
		x=[];y=[];
		for indx = 0:1:max_x*max_y-1
			xRange(indx+1) = fix(indx/max_y);
			yRange(indx+1) = rem(indx,max_y);
			if (N(indx+1) ~= 0)
				x = [x fix(indx/max_y)];
				y = [y rem(indx,max_y)];
				node_pd = [node_pd N(indx+1)];	 %node probability distribution
			end
		end
		stem3(xRange, yRange, zeros(1,max_x*max_y),'.w');
		hold all;
		stem3(x,y,node_pd,'fill', ':*r');
		title('3D DESTINATION PROBABILITY DISTRIBUTION FOR A NODE');
		xlabel('X');
		ylabel('Y');
		zlabel('Probability');
		
		
		xRange = min(period)-1:1:max(period)+1;
		N = hist(period,xRange);	  %# Bin the data
		N = N./numel(period);
		figure;
		stem(xRange,N);
		title('PACKET DELAY PROBABILITY DISTRIBUTION FOR A NODE');
		xlabel('Delay(Gen\_clk\_cycles)');
		ylabel('Probability');
		
		
		xRange = min(pkt_sizes)-1:1:max(pkt_sizes)+1;
		N = hist(pkt_sizes,xRange);	  %# Bin the data
		N = N./numel(pkt_sizes);
		figure;
		stem(xRange,N);
		title('PACKET SIZE PROBABILITY DISTRIBUTION FOR A NODE');
		xlabel('Delay(Packet\_quantum)');
		ylabel('Probability');
		
	end

%pkt_size_population = min_pkt_size : max_pkt_size;
%avg_pkt_size = (min_pkt_size + max_pkt_size)/2;
%pkt_size_pdf = gaussmf(pkt_size_population,[7 avg_pkt_size])/sum(gaussmf(pkt_size_population,[7 avg_pkt_size]));  %gaussian pribability distribution with peak at avg_pkt_size
%plot(pkt_size_pdf);
%randsample(pkt_size_population, req_count, true, pkt_size_pdf);
%bw_request = randsample([0,1,2,3], req_count, true, [0., 0.15, 0.05, 0.8]);

end


%//todo: check degree is within range for each traffic pattern. %degree >= 1???
%//fix: req_resp traffic ptrn
%//todo: make node index flexible. it can be x+y*MAX_X or x*MAX_Y+y
%//todo: remove extra space at the end of fprintf(temp_fid, text 