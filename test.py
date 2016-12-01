from TOSSIM import *
from tinyos.tossim.TossimApp import *
import sys

nodepool = []


def doexpr():
    n = NescApp()
    t = Tossim(n.variables.variables())
    m = t.mac();
    r = t.radio();
    f = open("15-15-tight-mica2-grid.txt", "r")

    lines = f.readlines()
    for line in lines:
        s = line.split()
        if (len(s) > 0 and s[0] == "gain"):
            r.add(int(s[1]), int(s[2]), float(s[3]))
    file1 = open("2.txt", "w")
    t.addChannel("endtoend",file1)
    t.addChannel("tran", sys.stdout)
    noise = open("meyer-short.txt", "r")
    lines = noise.readlines()
    for line in lines:
        str = line.strip()
        if (str != ""):
            val = int(str)
        for i in range(0, 225):
            temp = t.getNode(i)
            temp.addNoiseTraceReading(val)
            nodepool.append(temp)

    for i in range(0, 225):
        t.getNode(i).createNoiseModel()
    for i in range(0,225):
        t.getNode(i).bootAtTime(0)
    for i in range(1,50000000):
            t.runNextEvent()
    file1.close()



def calculate():
    f1=open ("1.txt","a")
    for i in range(0,225):
        f1.write( str( nodepool[i].getVariable("preambleTestC.level").getData()))
        f1.write("    ")
        for j in nodepool[i].getVariable("preambleTestC.t3").getData():
            f1.write(str(j))
            f1.write(',')
        f1.write('\n')
    f1.close()
if __name__ == "__main__":
        doexpr()
        calculate()


