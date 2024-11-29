set pkgs_dir "./packages"
set rtl_noc_dir "./rtl_noc"
set tb_dir "./testbench"


set incldir $pkgs_dir
set vlog_suppress "-suppress 2583,13314"
set vlog_flags "-incr -quiet"


# PACKAGES
vlog {*}$vlog_suppress $pkgs_dir/router_pkg.sv
vcom $pkgs_dir/router_pkg_vhdl.vhdl

# NOC RTL
vcom -2008 $rtl_noc_dir/rc.vhdl
#vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/rc.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/input_block_vc.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/n_deep_cir_fifo.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/sw_alloc_vc.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/sw_input_arb.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/sw_output_arb.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/vc_alloc.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/vc_input_arb.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/vc_output_arb.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/crossbar_vc.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/rev_xbar_vc.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/output_block_vc.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/router_vc.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/ctrl_web.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/data_web.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $rtl_noc_dir/noc2d_vc.sv

# TESTBENCH
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $tb_dir/tb_pkg.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $tb_dir/tb.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $tb_dir/pkt_gen.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $tb_dir/pkt_queue.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $tb_dir/pkt_tx.sv
vlog {*}$vlog_suppress {*}$vlog_flags +incdir+$incldir $tb_dir/pkt_rx.sv
