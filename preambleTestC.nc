#include <Timer.h>

#define roubletablemax 15
#define updatesleep 5000

module preambleTestC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as sleepTimer;
  uses interface Timer<TMilli> as LocalTimer;
  uses interface Timer<TMilli> as routerTimer;//��һ�����ݷ���
  uses interface Timer<TMilli> as waitforack;	//�ȴ�ACKʱ��
  
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
  uses interface Queue<Message*> as SendQueue;
  
}
implementation {
  int routetable[roubletablemax][2];//·�ɱ�
  bool first ;
  uint16_t counter;
  message_t pkt;
  int state;
  int awakestate;
  int sendtask;
  int level;
  int updateroute;
    bool busy;
 int sendflag;



  task void SendMessage();
  int getetx(uint16_t nodeid);
  uint16_t gettime();
  void updateroutetable();

  event void Boot.booted() {
	sendtask = 0;
    first = TRUE;
        updateroute=1;
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
		if(TOS_NODE_ID == 0)
			updateroutetable();
	  }
	  if(updateroute==0){
		state=0;
		call Timer0.startOneShot(100000);
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
          Message* msg= (Message*)(call Packet.getPayload(&pkt, sizeof(Message)));
    
	call SendQueue.enqueue(msg);
	sendtask = 1;
	if(awakestate==1&&sendtask==1)
	{
            //send preamble message 
	    post SendMessage();
	}
  }

  event void AMControl.stopDone(error_t err) 
  {
        if (err == SUCCESS) 
	{	  
            call Leds.led0Off();
	    state=0;
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
  

  //ACK�ȴ�
  event void waitforack.fired()//ACK���û�ڹ涨ʱ���ڷ��أ���ʼ�ش�
  {
	//����ȴ�����preamble��ack,�ط�preamble������ȴ�����data��ack���ط�data
       post SendMessage();
  }
  
  event void LocalTimer.fired()//ACK���û�ڹ涨ʱ���ڷ��أ���ʼ�ش�
  {
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
	Message* btrpkt = (Message*)payload;
	if(len == sizeof(Message))   
	{
		if(btrpkt->datatype == 1){
		//receive preamble ,send preamble ack ,stay awake 
			atomic{
			   sendflag=2;
			   post SendMessage();
			   call sleepTimer.stop();
			   call sleepTimer.startOneShot(2000);
			   }	
		}
		if(btrpkt->datatype == 2){
			atomic{
			   sendflag=3;
			   call waitforack.stop();
			   //judge
			   post SendMessage();
			}
		//receive preamble ack ,send data ,wait data ack
		}
		if(btrpkt->datatype == 3){
		//receive data ,send data ack��ת��
			if(TOS_NODE_ID==0)
			{
			
			}
			atomic{
			   sendflag=4;
			   post SendMessage();//��ack 
			   call SendQueue.enqueue(btrpkt);
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
		//�ж����޴������ݣ����򷢣�����˯
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
		//����·�ɱ�����
        int i;
		   for( i =0 ;i < roubletablemax ;i++ )
			if(routetable[i][0]==0)
			{
			   routetable[i][0]=btrpkt->nodeid;
			   routetable[i][1]=btrpkt->etx;
			   break;
			}
		   call sleepTimer.stop();
		   call routerTimer.startOneShot(updatesleep);	
		}
	}
        return msg;
  }


}