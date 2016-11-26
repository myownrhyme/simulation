import numpy as np
from pylab import *
delay=[]
def cal():
    file = open("2.txt")
    while 1:
        line = file.readline()
        if not line:
            break
        l=line.split()
        string=l[1].strip('():')
        m=int(l[3])
        if  len(l)== 6 and m != 0:
            s=int(l[2])-int(l[3])
            delay.append(s)
    file.close()
