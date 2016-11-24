file = open("2.txt")
while 1:
    line = file.readline()
    if not line:
        break
    l=line.split()
    string=l[1].strip('():')
    m=int(l[3])
    if  m==0:
        print line

