#include <Timer.h>
#include "BlinkToRadio.h"

module preambleTestC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as sleepTimer;

  uses interface Timer<TMilli> as nextSense;//��һ�����ݷ���
  uses interface Timer<TMilli> as waitforack;	//�ȴ�ACKʱ��
  
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
  
}
implementation {
  uint16_t counter;
  message_t pkt;
  int awakestate;
  int sendtask;
  void SendMessage();
  event void Boot.booted() 
  {
	sendtask = 0;
	call AMControl.start();
  }

event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) 
    {
	  call Leds.led0On();
	  awakestate = 1;
	  
	  if(sendtask == 1)
	  {
		sendtask = 0;
		SendMessage();		
	  }	  
	  
	  call sleepTimer.startOneShot(awaketime);
	  call Timer0.startOneShot(newRound);
	  	  
    }
    else {
        call AMControl.start();
        }
  }

  event void sleepTimer.fired(){
        if(awakestate == 1)
        {
		timetosleep = 1;
		if(timetosleep == 1 && sendtask==0)
		{
			call AMControl.stop();
		}
	}
	
	if(awakestate == 0)
	{
		call AMControl.start();
	}
  
  }

  event void Timer0.fired() {
	sendtask = 1;
	if(awakestate==1&&sendtask==1)
	{
	    SendPreambleMessage();
	}
  }

  event void AMControl.stopDone(error_t err) 
  {
        if (err == SUCCESS) 
	{	  
            call Leds.led0Off();
	    awakestate = 0;
	    timetosleep = 0;
	    call sleepTimer.startOneShot(sleeptime);	
	}
	else
	{
	  call AMControl.stop();
	}
  } 

  void SendMessage() {
	Message* btrpkt = (Message*)(call Packet.getPayload(&pkt, sizeof(Message)));
			
	if (call AMSend.send(0xffff,&pkt, sizeof(Message)) == SUCCESS) 
	{
	    call Leds.led1Toggle();
	}

  }

  //ACK�ȴ�
  event void waitforack.fired()//ACK���û�ڹ涨ʱ���ڷ��أ���ʼ�ش�
  {
        SendMessage();
  }
  
  
  event void Timer0.fired() {
  
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
	if (&pkt == msg) {

        }
	busy = FALSE; 
  }
  

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
	if(len == sizeof(PreambleMessage))   
	{
	    PreambleMessage* btrpkt=(PreambleMessage)payload;
	    call sleepTimer.stop();
	    //��װһ��preambleack������preambleack
	    SendMessage();
	}

	if(len == sizeof(PreambleMessageAck))
	{
	    //��װһ�����ݰ���������
	    sendMessage();
	}

	if(len == sizeof(DataMessage))
	{
	    DataMessage* btrpkt=(DataMessage*)payload;
	    //��װһ��ack����һ��dataack,��ʾ�����յ��ˣ�
	    ForwardMessage();
	}

	if(len == sizeof(DataAck))
	{
	    //������ɣ�ת�������Է���temp�Ƿ�Ϊ�գ���������ߣ��������͡�
	}
        return msg;
  }


}