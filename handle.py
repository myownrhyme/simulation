from __future__ import division
import numpy as np
from pylab import *
delay=[]
delay1=[]
def cal():
    file = open("2.txt")
    file1 = open("ctp1.txt")
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
    while 1:
        line = file1.readline()
        if not line:
            break
        l=line.split()
        string=l[1].strip('():')
        m=int(l[3])
        if len(l)==6 and m!=0:
            s=int(l[2])-int(l[3])
            delay1.append(s)
    file.close()
    file1.close()
    n=len(delay)

    x=range(0,1000,50)
    y=[]
    count=0
    for i in x:
        for j in delay:
            if j <=i:
                count=count+1
        print count,n
        y.append(float(count/n))
        count=0
    print y

    y1=[]
    count1=0
    for i in x:
        for j in delay1:
            if j<=i:
                count1=count1+1
        y1.append(float(count1/n))
        count1=0
    plot(x,y1,'-',color='r')
    plot(x,y)
    show()


if __name__== '__main__':
    cal()
