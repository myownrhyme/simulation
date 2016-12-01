def cal():
    f=open("2.txt","r")
    delay=[]
    while 1:
        line = f.readline()
        if not line:
            break
        s=line.split()
        delay.append([int(s[4])-int(s[5]),int(s[3])])
    f.close()
    sum=0
    for i in delay:
        if i[0]<10000:
            sum += i[0]
        print i
    print sum/len(delay)


if __name__=='__main__':
    cal()
