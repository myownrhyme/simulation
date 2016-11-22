from TOSSIM import *
from tinyos.tossim.TossimApp import *
import sys

nodepool = []


def doexpr():
    n = NescApp()
    t = Tossim(n.variables.variables())
    m = t.mac();
    r = t.radio();
    f = open("topo4perfect.txt", "r")

    lines = f.readlines()
    for line in lines:
        s = line.split()
        if (len(s) > 0 and s[0] == "gain"):
            r.add(int(s[1]), int(s[2]), float(s[3]))
    t.addChannel("senddelay", sys.stdout)
    file1 = open("1.txt", "w")
    t.addChannel("ack", sys.stdout)
    noise = open("meyer-short.txt", "r")
    lines = noise.readlines()
    for line in lines:
        str = line.strip()
        if (str != ""):
            val = int(str)
        for i in range(0, 4):
            temp = t.getNode(i)
            temp.addNoiseTraceReading(val)
            nodepool.append(temp)

    for i in range(0, 4):
        t.getNode(i).createNoiseModel()
    for i in range(0, 4):
        t.getNode(i).bootAtTime(0)

    for i in range(1, 5000):
        t.runNextEvent()
    file1.close()



def calculate():
    for i in range(0,4):
        print nodepool[i].getVariable("preambleTestC.SendQueue").getData()
        print (nodepool[i].getVariable("preambleTestC.t1").getData() if  nodepool[i].getVariable("preambleTestC.t1").getData() !=0 else '' )
        print (nodepool[i].getVariable("preambleTestC.t2").getData() if  nodepool[i].getVariable("preambleTestC.t2").getData() !=0 else '')
        print nodepool[i].getVariable("preambleTestC.level").getData()

if __name__ == "__main__":
        doexpr()
        calculate()


