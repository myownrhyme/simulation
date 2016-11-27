#include <Timer.h>

#define roubletablemax 15
#define updatesleep 5000

module preambleTestC {
    uses interface Boot;
    uses interface Leds;
	uses interface Timer<TMilli> as Timer0;
	uses interface Timer<TMilli> as sleepTimer;
	uses interface Timer<TMilli> as routerTimer;//��һ�����ݷ���
	uses interface Timer<TMilli> as waitforack;	//�ȴ�ACKʱ��
	uses interface Timer<TMilli> as dataTimer;
	uses interface LocalTime<TMilli> as LocalTime;
	uses interface Packet;
	uses interface AMPacket;
	uses interface AMSend;
	uses interface Receive;
	uses interface SplitControl as AMControl;
	uses interface Queue<Message*> as SendQueue;
	uses interface Random; 
}
implementation {
	int routetable[roubletablemax][2];//·�ɱ�
	uint16_t dest;
	uint16_t counter1;
    uint16_t counter;
	message_t pkt;
	int state;
	int awakestate;
	int sendtask;
	int level;
	int updateroute;
	bool busy;
	int sendflag;
	int pstate;
	uint32_t t1;
	uint32_t t2;
    uint32_t t3[100];
	int isupdate;
	exprData exp;
    int countpre ;
	void SendMessage();
	int getetx(uint16_t nodeid);
	uint16_t gettime();
	void updateroutetable();
	void inittemp();
	int getdest();
	void sort();
    int getroutetablesize();
	int getdest(){
		return routetable[0][0];
	}

	void inittemp(){
		int i=0;
		exp.countPre=0;
		exp.countPreAck=0;
		exp.countData=0;
		exp.countDataAck=0;
		exp.TimePoint1=0;
		exp.TimePoint2=0;
		exp.TimePoint3=0;
		exp.TimePoint4=0;
		for(i;i<roubletablemax;i++){
			routetable[i][0]=-1;
			routetable[i][1]=-1;}
	}
    int getetx(uint16_t nodeid){
        return    getroutetablesize();
    }
	int getroutetablesize(){
		int count=0;
		int i =0;
		for(i;i<roubletablemax;i++)
			if(routetable[i][0]!= -1)
				count++;
			else
				break;
		return count;
	}
	uint16_t gettime(){
		return 1;
	}


	event void Boot.booted() {
        int i;
        for(i=0;i<100;i++)
            t3[i]=0;
		level = 65535;
        countpre=0;
        counter=0;
        counter1=0;
		sendtask = 0;
		updateroute=1;
		isupdate=0;
		sendflag=0;
		inittemp();
		call AMControl.start();
	}

	void updateroutetable(){
		Message* msgpkt  = (Message*)(call Packet.getPayload(&pkt, sizeof(Message)));
		msgpkt->nodeid   = TOS_NODE_ID;
		msgpkt->datatype = 5;
		msgpkt->level    = level;
		msgpkt->data1    = 0;
		msgpkt->data2    = 0;
		msgpkt->remain   = 0;
		msgpkt->etx      = getetx(TOS_NODE_ID);
		msgpkt->time     = gettime();
		if (call AMSend.send(0xffff,&pkt, sizeof(Message)) == SUCCESS) 
		{
			call Leds.led1Toggle();
		}
	}

	event void AMControl.startDone(error_t err) {
		if (err == SUCCESS) 
		{
            counter++;
            t1=0;
            t2=0;
			awakestate=1;
			call Leds.led0On();
			if(updateroute==1){
				if(TOS_NODE_ID == 0){
					level = 0;
					updateroutetable();
				}
			}
			if(updateroute==0&&TOS_NODE_ID!=0){
	//			int i;
	//			for(i=0;i<5;i++)
	//				dbg("boot" ,"route table :%d\n" ,routetable[i][0]);
				pstate=0;
				state=0;
				call Timer0.startOneShot(5000);
			}	  
		}
		else {
			call AMControl.start();
		}
	}

	event void sleepTimer.fired(){
		updateroute=0;
		if(awakestate == 1)
		{
			call AMControl.stop();
		}

		if(awakestate == 0)
		{
			call AMControl.start();
		}

	}

	event void Timer0.fired() {
		//make a packet , put into queue ;
		sendtask = 1;
		if(awakestate==1&&sendtask==1)
		{
			state=1;
			//send preamble message 
			sendflag=1;
            if(TOS_NODE_ID!=0)
			SendMessage();
		}
	}

	event void AMControl.stopDone(error_t err) 
	{
		if (err == SUCCESS) 
		{	  
            call Leds.led0Off();
			state=0;
			pstate=0;
			awakestate=0;
			call sleepTimer.startOneShot(150000);	
		}
		else
		{
			call AMControl.stop();
		}
	} 

	void SendMessage() {
		Message* btrpkt = (Message*)(call Packet.getPayload(&pkt, sizeof(Message)));
		if(sendflag == 1){
			btrpkt->nodeid   = TOS_NODE_ID;
            btrpkt->dest     = TOS_NODE_ID;
			btrpkt->datatype = 1;
			btrpkt->level    = level;
			btrpkt->data1    = 0;
			btrpkt->data2    = 0;
			btrpkt->remain   = 0;
			btrpkt->etx      = getetx(TOS_NODE_ID);
			btrpkt->time     = gettime();
		}			
		if(sendflag == 2){
			btrpkt->nodeid   = TOS_NODE_ID;
            btrpkt->dest     = TOS_NODE_ID;
			btrpkt->datatype = 2;
			btrpkt->level    = level;
			btrpkt->data1    = 0;
			btrpkt->data2    = 0;
			btrpkt->remain   = 0;
			btrpkt->etx      = getetx(TOS_NODE_ID);
			btrpkt->time     = gettime();
		}
		if(sendflag == 3 ){
             if(sendtask==1){
                sendtask=0;
			btrpkt->nodeid   = TOS_NODE_ID;
            btrpkt->dest     = TOS_NODE_ID;
			btrpkt->datatype = 3;
			btrpkt->level    = level;
			btrpkt->data1    = t1;
			btrpkt->data2    = 0;
			btrpkt->remain   = 0;
			btrpkt->etx      = getetx(TOS_NODE_ID);
			btrpkt->time     = gettime();

            }
            else if(! (call SendQueue.empty())){
            Message* pkt = call SendQueue.head();
            //dbg("tran","send tran\n");
			btrpkt->nodeid   = pkt->nodeid;
            btrpkt->dest     = TOS_NODE_ID;
			btrpkt->datatype = pkt->datatype;
			btrpkt->level    = pkt->level;
			btrpkt->data1    = pkt->data1;
			btrpkt->data2    = pkt->data2;
			btrpkt->remain   = pkt->remain;
			btrpkt->etx      = getetx(TOS_NODE_ID);
			btrpkt->time     = gettime();
		    }
        }
		if(sendflag == 4){
			btrpkt->nodeid   = TOS_NODE_ID;
            btrpkt->dest     = TOS_NODE_ID;
			btrpkt->datatype = 4;
			btrpkt->level    = level;
			btrpkt->data1    = 0;
			btrpkt->data2    = 0;
			btrpkt->remain   = 0;
			btrpkt->etx      = getetx(TOS_NODE_ID);
			btrpkt->time     = gettime();
		}
		if(!busy){
			busy=TRUE;
	        if(sendflag == 1) 
				dest = 0xffff;
			if (call AMSend.send(dest,&pkt, sizeof(Message)) == SUCCESS) 
            {
                if(btrpkt->nodeid!=btrpkt->dest)
              //  dbg("tran","~~~~ data\n");
                call Leds.led1Toggle();
            }else{
                dbg("ack","send error/n");
            }
        }
        else{
            dbg("ack","busy error\n");
        }
    }

    event void routerTimer.fired()
    {
        //		dbg("ack" ,"%d send route message,my level is %d \n" ,TOS_NODE_ID,level);
        if(isupdate==0)
        {
            isupdate=1;	
            updateroutetable();}
        call AMControl.stop();
    }

    void sort(){
        int i;
        int j;
        for(i=0;i<roubletablemax;i++)
            for(j=i+1;j<roubletablemax;j++)
            {
                if(routetable[i][1] > routetable[j][1] && routetable[i][1]>0 && routetable[j][1]>0)
                {
                    int temp = routetable[i][1];
                    routetable[i][1]=routetable[j][1];
                    routetable[j][1]=temp;
                    temp = routetable[i][0];
                    routetable[i][0]=routetable[j][0];
                    routetable[j][0]=temp;
                }
            }

    }
    event void dataTimer.fired()
    {
    }

    //ACK�ȴ�
    event void waitforack.fired()//ACK���û�ڹ涨ʱ���ڷ��أ���ʼ�ش�
    {
        //����ȴ�����preamble��ack,�ط�preamble������ȴ�����data��ack���ط�data
        if(TOS_NODE_ID!=0)
        SendMessage();
    }


    event void AMSend.sendDone(message_t* msg, error_t err) {
        busy = FALSE; 
        if (&pkt == msg) {
            if(sendflag==1){
                counter1++;
                if (t1==0)
                t1=call LocalTime.get();
                //dbg("count","%d   %d    %d\n",t1,counter,counter1);
                call waitforack.startOneShot(500);	
            }
            if(sendflag==2)
            {
            }
            if(sendflag==3)
            {   
                countpre=0;
                inittemp();
                pstate=0;
                call SendQueue.dequeue();
                atomic{
                    if(call SendQueue.empty() ){
                        if(state ==1)
                            call sleepTimer.startOneShot(5000);
                    }
                    else{
                        atomic{
                            sendflag=1;
                            if(TOS_NODE_ID!=0)
                            SendMessage();
                        }
                    }
                }
            }
            if(sendflag==4){
                    atomic{
                        sendflag=1;
                        if(TOS_NODE_ID!=0)
                        SendMessage();
                    }
            }
        }
    }


    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
        Message* btrpkt = (Message*)payload;
        //	if(btrpkt->datatype==4)
        //		dbg("senddelay","receive 4\n");
        if(len == sizeof(Message))   
        {

            if(btrpkt->datatype == 4){
                int i;
                t2=call LocalTime.get();
                dbg("senddelay","receive 4\n");
                for(i=0;i<100;i++){
                    if(t3[i]==0){
                        dbg("count","%d   %d   %d    %d\n",t2,t1,counter,counter1);
                        t3[i]=t2-t1;
                        break;
                    }
                }
                t1=0;
                t2=0;
                dbg("senddelay", "receive 4 .\n");
            }
            if(btrpkt->datatype == 1){
                //receive preamble ,send preamble ack ,stay awake 
                //dbg("senddelay", "receive 1\n");
                atomic{
                    if(btrpkt->level>level){
                    sendflag=2;
                    dest = btrpkt->nodeid;
                    SendMessage();
                    }
                }
            }
            if(btrpkt->datatype == 2){
                if(TOS_NODE_ID==0){

                }
                else{
                    int i,s;
                    //dbg("senddelay", "receive 2 from %d\n",btrpkt->nodeid);
                    atomic{
                        if(btrpkt->level < level){
                            countpre++;
                            for(i=0;i<roubletablemax;i++)
                            {
                                if(routetable[i][0]==-1)
                                {
                                    routetable[i][0]=btrpkt->nodeid;
                                    s= (call Random.rand16())%29+50;
                                    routetable[i][1]= btrpkt->etx;
                                    break;
                                }
                            }
                        }
                        if(countpre>= 0.8*getroutetablesize() && countpre>=1){
                            call waitforack.stop();
                            sendflag=3;
                            sort();
                            dest=getdest();
                            for(i=0;i<15;i++){
                                if(routetable[i][0]>=0)
                                    dbg("ack","routetable %d\n",routetable[i][0]);
                            }
                            dbg("ack","send data to %d\n",getdest());
                            SendMessage();
                        }
                    }
                }
                //receive preamble ack ,send data ,wait data ack
            }

            if(btrpkt->datatype == 3){
                dbg("tran","receive %d data\n",btrpkt->nodeid);
                if(TOS_NODE_ID==0)
                {
                    btrpkt->data2=call LocalTime.get();
                    dbg("endtoend", "%d %d %d  \n",btrpkt->nodeid ,btrpkt->level,btrpkt->data2-btrpkt->data1);
                }
                else{ 
                    if(call SendQueue.enqueue(btrpkt)){
                        dbg("tran","store %d data",btrpkt->nodeid);
                    }
                    //if(TOS_NODE_ID > 3)
                    //dbg("senddelay", "receive data from %d\n",btrpkt->nodeid);
                }
                atomic{
                    sendflag=4;
                    dest = btrpkt->dest;
                    dbg("tran","send ack to %d\n",btrpkt->dest);
                    SendMessage();//��ack
                }
            }
            if(btrpkt->datatype == 5){
                if(TOS_NODE_ID!=0){
                    int r;
                    //	dbg("boot","receive route message from %d\n",btrpkt->nodeid);
                    if(btrpkt->level <= level){
                        if(level == 65535)
                            level =btrpkt->level+1;
                        r = (call Random.rand16())/65;	  
                        call routerTimer.startOneShot(9000+r);	
                    }
                }
            }
        }
        return msg;
    }


}
