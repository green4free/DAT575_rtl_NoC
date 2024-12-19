
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

run 12000ns
quit -f

