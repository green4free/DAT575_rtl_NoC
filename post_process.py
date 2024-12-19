
import subprocess
O_latency = subprocess.check_output('grep "avg_pkt_latency_gen_to_rx" outputs/*', shell=True)
O_injection = subprocess.check_output('grep "injection rate (pkts/node/ns)" outputs/*', shell=True)

lat = O_latency.decode("utf-8").split("\r\n")[:-1]
inject = O_injection.decode("utf-8").split("\r\n")[:-1]

entries = []
for L,I in zip(lat,inject):
    l_f, l_t, l_k, l = L.split(":")
    i_f, i_t, i_k, ir = I.split(":")
    assert l_f == i_f, f"{L}, {I}"
    s = len("outputs/")
    name, rest = l_f[s:].split("_stim_")
    traffic, rest = rest.split(".txt_")
    freq = rest.split(".l")[0]
    entries.append((name, traffic, int(freq), float(ir), float(l)))

entries.sort(key=lambda x: (x[1], x[0], -x[2], x[3], x[4]))

with open("results.csv", "w") as f:
    for name, traff, freq, ir, l in entries:
        f.write(f"{name},{traff},{freq},{ir},{l}\n")