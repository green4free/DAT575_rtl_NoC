quit -sim

do compile.tcl


set file_id 0;
set file_name a${file_id}.txt;
while {[file exists $file_name] == 1} {
set file_id [expr {$file_id + 1}];
set file_name a${file_id}.txt;
}



set vsim_suppress "-suppress 3009,2182"
vsim {*}$vsim_suppress  work.tb -voptargs=+acc -l ${file_name} -t ps


set WildcardFilter [lsearch -all $WildcardFilter .]

add wave -position insertpoint sim:/tb/clk
add wave -position insertpoint sim:/tb/arst_n

add wave -group tb_top_level -position insertpoint sim:/tb/*

add wave -group pkt_tx_0_0 -position insertpoint sim:/tb/GEN_X[0]/GEN_Y[0]/pkt_tx_i/*

add wave -group router_0_0 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[0]/router_i/*

add wave -group pkt_rx_0_1 -position insertpoint sim:/tb/GEN_X[0]/GEN_Y[1]/pkt_rx_i/*


add wave -group router_5_5 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[5]/gen_y[5]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[5]/gen_y[5]/router_i/outport
add wave -group router_4_5 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[4]/gen_y[5]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[4]/gen_y[5]/router_i/outport
add wave -group router_3_5 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[3]/gen_y[5]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[3]/gen_y[5]/router_i/outport
add wave -group router_2_5 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[2]/gen_y[5]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[2]/gen_y[5]/router_i/outport
add wave -group router_1_5 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[1]/gen_y[5]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[1]/gen_y[5]/router_i/outport
add wave -group router_0_5 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[5]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[5]/router_i/outport
add wave -group router_0_4 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[4]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[4]/router_i/outport
add wave -group router_0_3 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[3]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[3]/router_i/outport
add wave -group router_0_2 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[2]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[2]/router_i/outport
add wave -group router_0_1 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[1]/router_i/inport sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[1]/router_i/outport

# add wave -group ib_0_0_4 -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[0]/router_i/router_port[4]/ib_i/*
# add wave -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[0]/router_i/inport
# add wave -position insertpoint sim:/tb/noc2d_vc_i/gen_x[0]/gen_y[0]/router_i/outport

log -r /*

run 200ns
#configure wave -gridauto on
#configure wave -gridperiod 1ns
configure wave -signalnamewidth 1
configure wave -namecolwidth 200
configure wave -valuecolwidth 200
configure wave -waveselectenable 1
configure wave -waveselectcolor grey15
WaveRestoreZoom {0 ns} {45 ns}
#quit -sim
pause

