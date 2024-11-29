function dst_node_ids = centralized_tp(max_x, max_y, src_x, src_y, degree)
	plots_enable = 0;
	verify_for_8x8_noc = (max_x==8 && max_y==8 && src_x==4 && src_y==4 && degree<=4);
	
	
	dst_node_ids = [];
	for k=1:degree
		for x_offset=0:k
			for y_offset=0:k
				if x_offset+y_offset==k
					if (src_x-x_offset >= 0) && (src_y-y_offset >= 0)
						dst_node_ids = [dst_node_ids, (src_x-x_offset)*max_y+(src_y-y_offset)];
					end
					
					if (src_x+x_offset < max_x) && (src_y+y_offset < max_y)
						dst_node_ids = [dst_node_ids, (src_x+x_offset)*max_y+(src_y+y_offset)];
					end
					
					temp = (src_x-x_offset)*max_y+(src_y+y_offset);
					if (src_x-x_offset >= 0) && (src_y+y_offset < max_y) && ~ismember(temp, dst_node_ids)
						dst_node_ids = [dst_node_ids, temp];
					end
					
					temp = (src_x+x_offset)*max_y+(src_y-y_offset);
					if (src_x+x_offset < max_x) && (src_y-y_offset >= 0) && ~ismember(temp, dst_node_ids)
						dst_node_ids = [dst_node_ids, temp];
					end
				end
			end
		end
	end
	dst_node_ids = sort(dst_node_ids);
	
	
	
	if (plots_enable)
		dst_3d=zeros(max_x,max_y);
		for i=0:numel(dst_node_ids)-1
			dst_x = fix(dst_node_ids(i+1)/max_y);
			dst_y = rem(dst_node_ids(i+1),max_y);
			dst_3d(dst_x+1, dst_y+1) = abs(src_x-dst_x) + abs(src_y-dst_y);
		end
		
		figure;
		colormap(jet);
		imagesc(0:max_x-1, 0:max_y-1, dst_3d);
	end
	
	
	
	if (verify_for_8x8_noc)
		%Reference dst_node_ids for a 8x8 NoC node[4,4] and degree==[1,2,3,4]
		ref_dst = {	[28 35 37 44],
					[20 29 27 28 34 35 37 38 44 45 43 52],
					[12 21 19 20 30 26 29 27 28 33 34 35 37 38 39 44 45 43 46 42 52 53 51 60],
					[4 13 11 12 22 18 21 19 20 31 25 30 26 29 27 28 32 33 34 35 37 38 39 44 45 43 46 42 47 41 52 53 51 54 50 60 61 59]
				};
		
		
		if ~(all(ismember(ref_dst{degree}, dst_node_ids)) && numel(ref_dst{degree})==numel(dst_node_ids))
			sort(ref_dst{degree})
			sort(dst_node_ids)
			setdiff(ref_dst{degree}, dst_node_ids)	%find elements in ref_dst that are not in vector dst_node_ids
			error('Failed to generate correct dst_node_ids addresses for the neighbour traffic pattern');
		end
	end
end