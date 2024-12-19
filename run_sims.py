from jinja2 import Environment, FileSystemLoader

RC_MODES = {
    "xy":4,
    "num_credits":0,
    "valid_vcs":1,
    "random":2,
    "credit_weighted_random":3
}


# Load the template from the current directory
def generate_sv_from_template(template_file, output_file, parameters):
    env = Environment(loader=FileSystemLoader('.'))  # Current directory
    template = env.get_template(template_file)
    
    rendered_content = template.render(parameters)

    with open(output_file, 'w') as f:
        f.write(rendered_content)

import subprocess
from os import listdir

for routing in RC_MODES.keys():
    for traffic in ["stim_uniform.txt", "stim_transpose.txt"]:
        a = [20000, 10000, 5000, 2000, 1500, 1000, 750, 500, 300, 200, 150, 125, 100, 90, 85, 80, 75, 70, 65, 50, 30, 25, 20, 18]
        existing = listdir("outputs")
        P = list(filter(lambda p: f"{routing}_{traffic}_{p}.log" not in existing, a))
        for gen_clk_prd in P:
            params = {
                "trace_file": traffic,
                "measurement_cycles":10000,
                "gen_clk_prd": gen_clk_prd,
                "rc_mode": RC_MODES[routing]
            }
            generate_sv_from_template("tb_pkg.sv.j2", "rtl_simulation/packages/tb_pkg.sv", params)
            O = subprocess.check_output("questa --ws /home/magnusos/Documents/courses/DAT575/lab3/rtl_simulation --cmd /home/eda/ws0/run.sh", shell=True)
            open(f"outputs/{routing}_{traffic}_{gen_clk_prd}.log", "w").write(O.decode("utf-8"))
            print(f"{routing}_{traffic}_{gen_clk_prd} Done")