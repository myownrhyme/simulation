#include <Timer.h>

#define roubletablemax 15
#define updatesleep 5000

module preambleTestC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as sleepTimer;

  uses interface Timer<TMilli> as routerTimer;//下一个数据发送
  uses interface Timer<TMilli> as waitforack;	//等待ACK时间
  uses interface Timer<TMilli> as dataTimer;

  uses interface LocalTime<TMilli> as LocalTime;

  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
  uses interface Queue<Message*> as SendQueue;
  
}
implementation {
  int routetable[roubletablemax][2];//路由表
  int dest;
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
 int t1;
 int t2;


  task void SendMessage();
  int getetx(uint16_t nodeid);
  uint16_t gettime();
  void updateroutetable();
  void inittemp();
  int getdest();
  void sort();
  int getdest(){
	return routetable[0][0];
  }

  void inittemp(){
	int i=0;
	for(i;i<roubletablemax;i++){
		routetable[i][0]=-1;
		routetable[i][1]=-1;}
  }

  int getetx(uint16_t nodeid){
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
        level = -1;
	sendtask = 0;
        updateroute=1;
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
          awakestate=1;
          call Leds.led0On();
	  if(updateroute==1){
		if(TOS_NODE_ID == 0){
			level = 0;
			updateroutetable();
		}
	  }
	  if(updateroute==0){
		pstate=0;
		state=0;
		call Timer0.startOneShot(1000);
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
	    post SendMessage();
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
	    call sleepTimer.startOneShot(10000);	
	}
	else
	{
	  call AMControl.stop();
	}
  } 

  task void SendMessage() {
	Message* btrpkt = (Message*)(call Packet.getPayload(&pkt, sizeof(Message)));
	if(sendflag == 1){
		btrpkt->nodeid   = TOS_NODE_ID;
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
		btrpkt->datatype = 2;
		btrpkt->level    = level;
		btrpkt->data1    = 0;
		btrpkt->data2    = 0;
	        btrpkt->remain   = 0;
	        btrpkt->etx      = getetx(TOS_NODE_ID);
		btrpkt->time     = gettime();
	}
	if(sendflag == 3){
		btrpkt->nodeid   = TOS_NODE_ID;
		btrpkt->datatype = 3;
		btrpkt->level    = level;
		btrpkt->data1    = 0;
		btrpkt->data2    = 0;
	        btrpkt->remain   = 0;
	        btrpkt->etx      = getetx(TOS_NODE_ID);
		btrpkt->time     = gettime();
	}
	if(sendflag == 4){
		btrpkt->nodeid   = TOS_NODE_ID;
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
		 if(sendflag == 3)
			dest = getdest();
		if (call AMSend.send(dest,&pkt, sizeof(Message)) == SUCCESS) 
		{
			call Leds.led1Toggle();
		}
	}
  }

  event void routerTimer.fired()
  {
	updateroutetable();
	call AMControl.stop();
  }
  
 void sort(){
	int i;
	int j;
	for(i=0;i<roubletablemax;i++)
	for(j=i+1;j<roubletablemax;j++)
	{
		if(routetable[i][1] > routetable[j][1])
		{
			int temp = routetable[i][1];
			routetable[i][1]=routetable[j][1];
			routetable[j][1]=temp;
		}
	}

}
  event void dataTimer.fired()
  {
	sendflag=3;
	sort();
	post SendMessage();
  }

  //ACK等待
  event void waitforack.fired()//ACK如果没在规定时间内返回，则开始重传
  {
	//如果等待的是preamble的ack,重发preamble，如果等待的是data的ack，重发data
       post SendMessage();
  }
  

  event void AMSend.sendDone(message_t* msg, error_t err) {
	if (&pkt == msg) {
		if(sendflag==1){
			pstate=1;
			t1=call  LocalTime.get();
			call waitforack.startOneShot(2000);	
		}
		if(sendflag==2)
		{
		}
		if(sendflag==3)
		{
			call SendQueue.dequeue();
			if(call SendQueue.empty() )
				if(state ==1)
					call sleepTimer.startOneShot(2000);
			else{
				atomic{
				sendflag=3;
				post SendMessage();
				}
			}	
		}
        }
	busy = FALSE; 
  }
  

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
	Message* btrpkt = (Message*)payload;
	if(len == sizeof(Message))   
	{
		if(btrpkt->datatype == 1){
		//receive preamble ,send preamble ack ,stay awake 
		     atomic{
			   sendflag=2;
			   dest = btrpkt->nodeid;
			   post SendMessage();
			   call sleepTimer.stop();
			   if(state == 1){
				call sleepTimer.startOneShot(2000);
			   }
	             }	
		}
		if(btrpkt->datatype == 2){
			atomic{
			   call waitforack.stop();
			   call dataTimer.startOneShot(2000);
			}
		//receive preamble ack ,send data ,wait data ack
		}
		if(btrpkt->datatype == 3){
		//receive data ,send data ack，转发
			if(TOS_NODE_ID==0)
			{
			
			}
			atomic{
			   sendflag=4;
			   dest = btrpkt->nodeid;
			   post SendMessage();//回ack 
			   call SendQueue.enqueue(btrpkt);
			}
			if(pstate == 0){
			atomic{
				sendflag=1;
				post SendMessage();
				}
			}
			if(pstate == 1)
			atomic{
				sendflag=3;
				post SendMessage();
			}
		}
		if(btrpkt->datatype == 4){
		//判断有无待发数据，有则发，无则睡
			t2=call LocalTime.get();
			dbg("senddelay", "%s .\n", t2-t1);
		}
		if(btrpkt->datatype == 5){
		//更新路由表操作
                   int i;
		   for( i =0 ;i < roubletablemax ;i++ ){
			if(routetable[i][0]==-1)
			{
			   routetable[i][0]=btrpkt->nodeid;
			   routetable[i][1]=btrpkt->etx;
			   break;
			}
		   }
	           if(level == -1)
		       level =btrpkt->level+1;
		   call routerTimer.startOneShot(updatesleep);	
		}
	}
        return msg;
  }


}
