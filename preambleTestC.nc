#include <Timer.h>
#include "BlinkToRadio.h"

#define roubletablemax 15
#define updatesleep 5000

module preambleTestC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as sleepTimer;
  uses interface Timer<TMilli> as LocalTimer;
  uses interface Timer<TMilli> as routerTimer;//下一个数据发送
  uses interface Timer<TMilli> as waitforack;	//等待ACK时间
  
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
  interface Queue<Message*> as SendQueue;
  
}
implementation {
  int routetable[roubletablemax][2];//路由表
  bool first =true;
  uint16_t counter;
  message_t pkt;
  int state;
  int awakestate;
  int sendtask;
  int level;
  int updateroute;


  //指定level
  if(TOS_NODE_ID==0)
	level=0;
  else if(TOS_NODE_ID>0 && TOS_NODE_ID<50)
	level = 1;


  void SendMessage();
  void getetx(uint16_t nodeid);
  void gettime();
  void updateroutetable();

  event void Boot.booted() {
	sendtask = 0;
        updateroute=1;
	call AMControl.start();
  }

  void updateroutetable(){
          Message* pkt  = (Message*)(call Packet.getPayload(&pkt, sizeof(Message)));
          pkt->nodeid   = TOS_NODE_ID;
          pkt->datatype = 5;
          pkt->level    = level;
          pkt->data1    = 0;
          pkt->data2    = 0;
          pkt->remain   = 0;
	  pkt->etx      = getetx();
          pkt->time     = gettime();
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
		if(TOS_NODE_ID == 0)
			updateroutetable();
	  }
	  if(updateroute==0){
		state=0;
		call Timer0.startOneShot(newRound);
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
	SendQueue.enqueue();
	sendtask = 1;
	if(awakestate==1&&sendtask==1)
	{
            //send preamble message 
	    SendMessage();
	}
  }

  event void AMControl.stopDone(error_t err) 
  {
        if (err == SUCCESS) 
	{	  
            call Leds.led0Off();
	    state=0;
	    awakestate=0;
	    call sleepTimer.startOneShot(sleeptime);	
	}
	else
	{
	  call AMControl.stop();
	}
  } 

  task void SendMessage() {
	Message* btrpkt = (Message*)(call Packet.getPayload(&pkt, sizeof(Message)));
	if(sendflag == 1){
		pkt->nodeid   = TOS_NODE_ID;
		pkt->datatype = 1;
		pkt->level    = level;
		pkt->data1    = 0;
		pkt->data2    = 0;
	        pkt->remain   = 0;
	        pkt->etx      = getetx();
		pkt->time     = gettime();
	}			
	if(sendflag == 2){
		pkt->nodeid   = TOS_NODE_ID;
		pkt->datatype = 2;
		pkt->level    = level;
		pkt->data1    = 0;
		pkt->data2    = 0;
		pkt->remain   = 0;
		pkt->etx      = getetx();
		pkt->time     = gettime();
	}
	if(sendflag == 3){
	  pkt->nodeid   = TOS_NODE_ID;
          pkt->datatype = 3;
          pkt->level    = level;
          pkt->data1    = 0;
          pkt->data2    = 0;
          pkt->remain   = 0;
	  pkt->etx      = getetx();
          pkt->time     = gettime();
	}
	if(sendflag == 4){
	  pkt->nodeid   = TOS_NODE_ID;
          pkt->datatype = 4;
          pkt->level    = level;
          pkt->data1    = 0;
          pkt->data2    = 0;
          pkt->remain   = 0;
	  pkt->etx      = getetx();
          pkt->time     = gettime();
	}
	if (call AMSend.send(0xffff,&pkt, sizeof(Message)) == SUCCESS) 
	{
	    call Leds.led1Toggle();
	}

  }

  event void routerTimer.fired()
  {
	updateroutetable();
	call AMControl.stop();
  }
  

  //ACK等待
  event void waitforack.fired()//ACK如果没在规定时间内返回，则开始重传
  {
	//如果等待的是preamble的ack,重发preamble，如果等待的是data的ack，重发data
        SendMessage();
  }
  
  

  event void AMSend.sendDone(message_t* msg, error_t err) {
	if (&pkt == msg) {
		if(sendflag==1){
			state=1;
			call waitforack.startOneShot(2000);	
		}
		if(sendflag==2)
		{
			
		}
		if(sendflag==3)
		{
			call waitforack.startOneShot(2000);
		}
        }
	busy = FALSE; 
  }
  

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
	Message* btrpkt = (message*)payload;
	if(len == sizeof(Message))   
	{
		if(btrpkt->datatype == 1){
		//receive preamble ,send preamble ack ,stay awake 
			atomic{
			   sendflag=2;
			   post SendMessage();
			   sleepTimer.stop();
			   sleepTimer.startOneshot(waitdecidetime);
			   }	
		}
		if(btrpkt->datatype == 2){
			atomic{
			   sendflag=3;
			   waitforack.stop();
			   //judge
			   post SendMessage();
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
			   post SendMessage();//回ack 
			   call SendQueue.enqueue();
			}
			if(state == 0){
				sendflag=1;
				post SendMessage();
			}
			if(state == 1)
				sendflag=3;
				post SendMessage();
			
		}
		if(btrpkt->datatype == 4){
		//判断有无待发数据，有则发，无则睡
			call SendQueue.dequeue();
			if(call SendQueue.empty())
				call waitforack.startOneShot(2000);
			else{
				atomic{
				sendflag=3;
				post SendMessage();
				}
			}
		}
		if(btrpkt->datatype == 5){
		//更新路由表操作
		   for(int i =0 ;i < roubletablemax ;i++ )
			if(routetable[i][0]==0)
			{
			   routetable[i][0]=btrpkt->nodeid;
			   routetable[i][1]=btrpkt->etx;
			   break;
			}
		   call sleepTimer.Stop();
		   call routerTimer.startOneShot(updatesleep);	
		}
	}
        return msg;
  }


}