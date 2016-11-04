#include <Timer.h>
#include "BlinkToRadio.h"

#define newRound 600000
#define nextdata 100
#define waitforack_time 10000

#define packetlength 17
#define packetcounter 5
#define waitforack_number 5

module preambleTestC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  
  uses interface Timer<TMilli> as nextSense;//下一个数据发送
  uses interface Timer<TMilli> as waitforack;	//等待ACK时间
  
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
  
//  uses interface Timer<TMilli> as SenseTimer;
  
    uses interface Read<uint16_t> as VoltageRead;	  ///wrc-- 20101118
	uses interface Read<uint16_t> as TempRead;       //wrc-- 2011-1-11
	uses interface Read<uint16_t> as LightRead;
	uses interface Read<uint16_t> as HumiRead;
}
implementation {

  uint16_t counter;
  message_t pkt;
  bool busy = FALSE;
  bool IsRelay = FALSE; //判断是否转发数据包
  
  
  int data[TOTAL_SENSE_DATA];			//节点采集到数据后，放到这个数组中
  bool senseDone[TOTAL_SENSE_TAG];
  //tempdata用来存储接收到1组转发包的所有信息
  //packetcounter为5，即可缓存包个数为5个
  //packetlength为每一个包的长度为17个int变量字节
  //其中第一个包为控制包
  //后面的包为数据包
  //控制包中 1.ID,2.flag,3.counter,4.segment,5.all_segment,6.hop,7--11.relay,12-17.remain
  //数据包中 1.ID,2.flag,3.counter.4.segment,5-16.data,17.remain
  //其中数据包中data部分,5.Voltage,6.Light,7.Temp,8.Humi,9.rssi,10--16 后续使用
  int	tempdata[packetcounter][packetlength];  
  
  int	temp_i;
  int	temp_j;
  
  nx_uint16_t my_humi;
  nx_uint16_t my_temp;             //wrc-- 2011-1-11
  nx_uint16_t number;
  uint8_t i;                           //用来初始化以数据的
  
  uint16_t datatype;//用来进行判断控制包和数据包
  
  uint16_t packetSegment;//用来记录分片号总数
  uint16_t packetnumber;//接收到的转发数据包个数
  int	packetID;//接收到的转发数据包的ID
  int	packetCounter;//所属ID的数据包的个数
  int	segment;//分包号
  int	ack_receive;//是否接收到ACK，0为未收到，1为接收到，2为未给上一个节点返回ACK,3为未赋值状态
  int	ack_target;//ACK返回的目的节点ID
  int	ack_number;//等待ACK，并进行重传的次数
  int	temp_receive;
  
  int	level;
  
  void calc_SHT_(uint16_t p_humidity ,uint16_t p_temperature);
  void SenseAllData();
  void SendMessage();

  void InitialTemp();
  
  event void Boot.booted() 
  {
  
  data[VOLTAGE_DATA] =0;      
  data[LIGHT_DATA] = 0;
  data[TEMP_INDEX]=0;
  data[HUMI_DATA] =0;
  number=0;
  //datatype初值设置为0可以方便，后续tempdata中使用
  datatype=0;
  segment=1;//分包号
  
  
  //增加level;
  if(TOS_NODE_ID>750 &&TOS_NODE_ID<760)
  {level = 1;}
  else  if(TOS_NODE_ID>760 &&TOS_NODE_ID<770)
  {level = 2;}
  else  if(TOS_NODE_ID>770 &&TOS_NODE_ID<780)
  {level = 3;}
  else  if(TOS_NODE_ID>780 &&TOS_NODE_ID<790)
  {level = 4;}
 
  
  
  //初始化缓冲区和转发相关参数
  InitialTemp();
  packetID=0;
  packetCounter=0;
  packetnumber=0;
  packetSegment=-1;
  
  //ACK未赋值状态
  ack_receive=3;
  ack_target=-1;//未赋值为-1
  ack_number=0;
  temp_receive=0;
  
   call AMControl.start();
  }
/*数据接收*/

    void SenseAllData()
	{
		if(!busy){                                   
			for(i=0; i<TOTAL_SENSE_TAG; i++)
				senseDone[i] = FALSE;
			
			call VoltageRead.read();    
		}
			
	}
	
	event void VoltageRead.readDone(error_t err, uint16_t val)
	{
		if(SUCCESS == err)                
		{
			data[VOLTAGE_DATA] = val;
			senseDone[VOLTAGE_INDEX] = TRUE;
		}
		call LightRead.read();	
	}
	
	event void LightRead.readDone(error_t err, uint16_t val)
	{
		if(SUCCESS == err)
		{
			data[LIGHT_DATA] = val;
			senseDone[LIGHT_INDEX] = TRUE;
		}
		call TempRead.read();
	}
	
	event void TempRead.readDone(error_t err, uint16_t val)   
	{
		if(SUCCESS == err)
		{
			my_temp = val;
			senseDone[TEMP_INDEX] = TRUE;
		}
		call HumiRead.read();
	}
	
	event void HumiRead.readDone(error_t err, uint16_t val){
		if(SUCCESS == err)
		{
			senseDone[HUMI_INDEX] = TRUE;
			calc_SHT_(val, my_temp);
		}
		
	}
	
	void calc_SHT_(uint16_t p_humidity ,uint16_t p_temperature){ 
	atomic data[TEMP_DATA]=p_temperature; 
	atomic data[HUMI_DATA]=p_humidity;
	
  }
  
//清楚缓冲区
void InitialTemp()
{	
	for(temp_i=0;temp_i<packetcounter;temp_i++)
	{
		for(temp_j=0;temp_j<packetlength;temp_j++)
				tempdata[temp_i][temp_j]=0;
	}
}

  event void AMControl.startDone(error_t err) {
	call Leds.led0On();
    if (err == SUCCESS) 
	{
	  call Timer0.startPeriodic(newRound);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {

  }

  void SendMessage() {
  

	Message* btrpkt = (Message*)(call Packet.getPayload(&pkt, sizeof(Message)));
		
	if(btrpkt == NULL)
		return ;

	//ack_receive为2表示，接收到上一个节点发送的信息，但是未返回ACK的状态
	if(ack_receive==2)
	{
	//ACK包转发回上一层节点
	//固定位赋值
		//ACK返回的ID
		btrpkt->nodeid=TOS_NODE_ID;
		btrpkt->flag=3;//ACK包为3
		btrpkt->counter=0;
		btrpkt->segment=0;//分片号+1表示正确接收所有数据包
	//自由段赋值,ACK全为0
		btrpkt->data1=0;
		btrpkt->data2=0;
		btrpkt->data3=0;
		btrpkt->data4=0;
		btrpkt->data5=0;
		btrpkt->data6=0;
		btrpkt->data7=0;
		btrpkt->data8=0;
		btrpkt->data9=0;
		btrpkt->data10=0;
		btrpkt->data11=0;
		btrpkt->data12=0;
		btrpkt->remain=0;
	//ack_target为ACK的返回目的节点ID
	
		if(tempdata[0][5]==0)
		{
			ack_target=tempdata[0][0];
		}
		else if(tempdata[0][5]==1)
		{
			ack_target=tempdata[0][0];
		}
		else if(tempdata[0][5]==2)
		{
			ack_target=tempdata[0][6];
		}
		else if(tempdata[0][5]==3)
		{
			ack_target=tempdata[0][7];
		}
		else if(tempdata[0][5]==4)
		{
			ack_target=tempdata[0][8];
		}
		else if(tempdata[0][5]==5)
		{
			ack_target=tempdata[0][9];
		}
		
		if (call AMSend.send(ack_target, &pkt, sizeof(Message)) == SUCCESS) 
		{	
			//akc_receive为3，表示ACK未赋值
			ack_receive=3;
			call Leds.led1Toggle();
		}
		//先发送ACK后立刻转发消息
		call nextSense.startOneShot(nextdata);
		return ;
	}
	
	
	//转发包
	if(TOS_NODE_ID!=0&&!busy && IsRelay==TRUE)
	{
	//转发情况下，先发控制包，再发数据包
	//datatype用来控制发送控制包或者数据包
		if(datatype==0)
		{
		//控制包转发
		//固定位赋值
			btrpkt->nodeid=tempdata[datatype][0];
			btrpkt->flag=tempdata[datatype][1];//控制包1
			btrpkt->counter=tempdata[datatype][2];
			//转发时segment可以从tempdata中存取，此处tempdata修改后应该有变化
			btrpkt->segment=tempdata[datatype][3];
		//自由段赋值
			
		//需要添加分片号总数。转发用
			btrpkt->data1=tempdata[datatype][4];
			btrpkt->data2=tempdata[datatype][5];
			
			btrpkt->data3=tempdata[datatype][6];
			btrpkt->data4=tempdata[datatype][7];
			btrpkt->data5=tempdata[datatype][8];
			btrpkt->data6=tempdata[datatype][9];
			btrpkt->data7=tempdata[datatype][10];

		//预留字段,其内容都为0
			btrpkt->data8=level;
			btrpkt->data9=tempdata[datatype][12];
			btrpkt->data10=tempdata[datatype][13];
			btrpkt->data11=tempdata[datatype][14];
			btrpkt->data12=tempdata[datatype][15];
			btrpkt->remain=tempdata[datatype][16];
		}
		else
		{
		//数据包进行转发
		//固定位赋值
			btrpkt->nodeid=tempdata[datatype][0];
			btrpkt->flag=tempdata[datatype][1];//数据包为2
			btrpkt->counter=tempdata[datatype][2];
			//转发时segment可以从tempdata中存取，此处tempdata修改后应该有变化
			btrpkt->segment=tempdata[datatype][3];
		//自由段赋值
		//数据包自由段主要用来进行数据的传输
		//目前测试阶段，使用7个数据包，其他数据包为0
		//v,l,t,h,r
			btrpkt->data1=tempdata[datatype][4];
			btrpkt->data2=tempdata[datatype][5];
			btrpkt->data3=tempdata[datatype][6];
			btrpkt->data4=tempdata[datatype][7];
			btrpkt->data5=tempdata[datatype][8];
		
		//保留7个数据位,内容为0
			btrpkt->data6=tempdata[datatype][9];
			btrpkt->data7=tempdata[datatype][10];
			btrpkt->data8=tempdata[datatype][11];
			btrpkt->data9=tempdata[datatype][12];
			btrpkt->data10=tempdata[datatype][13];
			btrpkt->data11=tempdata[datatype][14];
			btrpkt->data12=tempdata[datatype][15];
		//预留字段
			btrpkt->remain=tempdata[datatype][16];
		}

		
	
	}
	//自发包
	else if (TOS_NODE_ID!=0&&!busy &&IsRelay==FALSE) 
	{
		//先发送控制包
		if(datatype==0)
		{
		//固定字段赋值
			btrpkt->nodeid=TOS_NODE_ID;
			btrpkt->flag=1;//控制包1
			btrpkt->counter=counter;
			btrpkt->segment=segment;
		
		//自由段赋值
		//需要添加分片号总数。自发用
		//目前根据需要，设置为总分片号为2
			btrpkt->data1=2;	
			btrpkt->data2=0;
		
			
		
		//目前为5跳，所以tempdata要进行大量修改
			btrpkt->data3=0xffff;
			btrpkt->data4=0xffff;
			btrpkt->data5=0xffff;
			btrpkt->data6=0xffff;
			btrpkt->data7=0xffff;
		//预留字段
			btrpkt->data8=level;//增加level
			btrpkt->data9=0;
			btrpkt->data10=0;
			btrpkt->data11=0;
			btrpkt->data12=0;
			
			btrpkt->remain=0;
		}
		//接着发送数据包
		else
		{
		//固定字段赋值
			btrpkt->nodeid=TOS_NODE_ID;
			btrpkt->flag=2;//数据包为2
			btrpkt->counter=counter;
			//转发时segment可以从tempdata中存取，此处tempdata修改后应该有变化
			btrpkt->segment=segment;
		//自由段赋值
		//数据包自由段主要用来进行数据的传输
		//目前测试阶段，使用7个数据包，其他数据包为0
			btrpkt->data1=1;
			btrpkt->data2=data[VOLTAGE_DATA];
			btrpkt->data3=data[LIGHT_DATA];
			btrpkt->data4=data[TEMP_DATA];
			btrpkt->data5=data[HUMI_DATA];
		
		//保留7个数据位
			btrpkt->data6=0;//rssi值
			btrpkt->data7=0;
			btrpkt->data8=0;
			btrpkt->data9=0;
			btrpkt->data10=0;
			btrpkt->data11=0;
			btrpkt->data12=0;
		//预留字段
			btrpkt->remain=0;
		}
    }
	
	
	//发送消息，无论是自身产生的或者需要转发的消息
	//busy = TRUE;
	

	
	if (call AMSend.send(0xffff,&pkt, sizeof(Message)) == SUCCESS) 
	{
		
		//datatype目前主要用来控制发送控制和数据包的个数
		datatype++;
		//segment用来控制目前分片发送到第几个
		segment++;
		call Leds.led1Toggle();
	}


	
	//目前发送一个控制包和一个数据包进行测试，共2个包
	if(datatype<2)
	{
		call nextSense.startOneShot(nextdata);
		//call Leds.led2Toggle();
	}
	else
	{
		datatype = 0;
		segment=1;//分包
		
		//akc_receive为0表示正在等待ACK返回，未收到ACK状态
		ack_receive=0;
		
		call waitforack.startOneShot(waitforack_time);//开始等待ACK
		//call Leds.led0Toggle();
		
	}
  }
  

  //ACK等待
  event void waitforack.fired()//ACK如果没在规定时间内返回，则开始重传
  {

	if(ack_receive==0 && ack_number<waitforack_number-1)	//则仍处于等待ACK阶段
	{
		ack_number++;
		busy=FALSE;
		SendMessage();				
	}
	else//成功接收到ACK或者重传次数过多
	{
		//如果发送阶段为转发，则若未收到ACK则转发标志不变
		//如果发送阶段为转发阶段，且收到ACK则转发标志变化
		if(temp_receive==1)
		{
			temp_receive=0;
			//进行转发
			ack_receive=2;
			IsRelay=TRUE;//进行转发消息
			call Leds.led2Toggle();//转发亮   
			call nextSense.startOneShot(nextdata);
		}
		else
		{
			if(IsRelay == TRUE)
				IsRelay=FALSE;
			
			ack_receive=3;
			ack_number=0;
			//清楚缓冲区
			InitialTemp();
		}
		
	}
	
  }
  
  event void nextSense.fired()
  {
		SendMessage();  
  }
  
  event void Timer0.fired() {
  

	if(IsRelay==FALSE)
	{
		//如果不等待ACK返回
		
		
		if(ack_receive!=0)
		{
			counter++;
			busy=FALSE;
			SenseAllData(); 
			SendMessage();
		}

	}
	else
	{
		//如果不等待ACK返回
		if(ack_receive!=0)
		{
			busy=FALSE;
			SendMessage();
		}

	}
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    if (&pkt == msg) {

    }
	busy = FALSE; 
  }
  
 
//对于接收的数据包来说，RECEIVE只进行存储，不进行发送操作，发送全部在sendmessage
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
	
	
	Message* btrpkt=(Message*)payload;
	
	//MessageControl和MessageData数据包格式相同，但是其解释方式不同
    if (len < (sizeof(Message)+sizeof(uint16_t)) && len >(sizeof(Message)-sizeof(uint16_t)) ) 
	{	
		//btrpkt->flag==1为控制包
        if (!busy && packetnumber==0 && btrpkt->flag==1 )                 
		{
			if(btrpkt->data8-level!=1)
			{
				return msg;
			}
		//接收到的第1个包为控制包
		//临时存储packet的ID和Counter用来进行判断后续数据包是否和控制包为一组
			packetID=btrpkt->nodeid;
			packetCounter=btrpkt->counter;
			//这组控制包和数据包的总个数
			packetSegment=btrpkt->data1;
		
		//控制包中固定位赋值
			//ID
			tempdata[packetnumber][0]=btrpkt->nodeid;
			//flag
			tempdata[packetnumber][1]=btrpkt->flag;
			//counter
			tempdata[packetnumber][2]=btrpkt->counter;
			//segment
			tempdata[packetnumber][3]=btrpkt->segment;
			
		//控制包中自由段赋值
			//all_segment
			tempdata[packetnumber][4]=btrpkt->data1;
			//hop+1
			tempdata[packetnumber][5]=btrpkt->data2+1;
			
			//relay1--relay5
			tempdata[packetnumber][6]=btrpkt->data3;
			tempdata[packetnumber][7]=btrpkt->data4;
			tempdata[packetnumber][8]=btrpkt->data5;
			tempdata[packetnumber][9]=btrpkt->data6;
			tempdata[packetnumber][10]=btrpkt->data7;
			
			//remain
			tempdata[packetnumber][11]=btrpkt->data8;
			tempdata[packetnumber][12]=btrpkt->data9;
			tempdata[packetnumber][13]=btrpkt->data10;
			tempdata[packetnumber][14]=btrpkt->data11;
			tempdata[packetnumber][15]=btrpkt->data12;
			tempdata[packetnumber][16]=btrpkt->remain;
			
		
			
			if(btrpkt->data2+1==1)
				tempdata[packetnumber][6] = TOS_NODE_ID;
			if(btrpkt->data2+1==2)
				tempdata[packetnumber][7] = TOS_NODE_ID;				
			if(btrpkt->data2+1==3)
				tempdata[packetnumber][8] = TOS_NODE_ID;
			if(btrpkt->data2+1==4)
				tempdata[packetnumber][9] = TOS_NODE_ID;
			if(btrpkt->data2+1==5)
				tempdata[packetnumber][10] = TOS_NODE_ID;
			
			  packetnumber++;            
        }
		
		//btrpkt->flag==2为数据包
		//packetnumber<packetSegment可以动态的进行数据包的接收
		if(!busy && packetnumber<packetSegment && btrpkt->flag==2 )
		{
			//从第2个包开始进行数据包的接收
			if(packetID == btrpkt->nodeid && packetCounter == btrpkt->counter)
			{
				
			//数据包中固定位赋值
				//ID
				tempdata[packetnumber][0]=btrpkt->nodeid;
				//flag
				tempdata[packetnumber][1]=btrpkt->flag;
				//counter
				tempdata[packetnumber][2]=btrpkt->counter;
				//segment
				tempdata[packetnumber][3]=btrpkt->segment;
			//数据包中自由段赋值	
				//Voltage
				tempdata[packetnumber][4]=btrpkt->data1;
				//Light
				tempdata[packetnumber][5]=btrpkt->data2;
				//Temp
				tempdata[packetnumber][6]=btrpkt->data3;
				//Humi
				tempdata[packetnumber][7]=btrpkt->data4;
				//rssi
				tempdata[packetnumber][8]=btrpkt->data5;
				
			//数据包中尚未使用的数据段
				tempdata[packetnumber][9]=btrpkt->data6;
				tempdata[packetnumber][10]=btrpkt->data7;
				tempdata[packetnumber][11]=btrpkt->data8;
				tempdata[packetnumber][12]=btrpkt->data9;
				tempdata[packetnumber][13]=btrpkt->data10;
				tempdata[packetnumber][14]=btrpkt->data11;
				tempdata[packetnumber][15]=btrpkt->data12;
				
			//填充位
				tempdata[packetnumber][16]=btrpkt->remain;
				
				packetnumber++;
			}
			else
			{
				//释放缓冲区，packetID,packetCounter,packetnumber清空
				InitialTemp();
				packetID=0;
				packetCounter=0;
				packetnumber=0;
				packetSegment=-1;
			}
		}
		
		
		
		
    }
	
	//如果收到的包为ACK包,且未收到ACK
	if(!busy  && btrpkt->flag==3)
	{
		//ack_receive为1，表示成功向下一个节点发送数据的状态
		
		ack_receive=1;
		ack_number=waitforack_number+1;
		
		call Leds.led0Toggle();//收到ACK 
	}
	
	if(!busy && packetnumber==packetSegment )
	{
		//调用sendmessage，进行消息转发
		
		//ack_receive为2表示，接收到上一个节点发送的信息，但是为返回ACK的状态
		
		
		packetID=0;
		packetCounter=0;
		packetnumber=0;
		packetSegment=-1;
		
		
		if(ack_receive==0)
		{
			temp_receive=1;
		}
		else
		{
			ack_receive=2;
			IsRelay=TRUE;//进行转发消息
			call Leds.led2Toggle();//转发亮   
			call nextSense.startOneShot(nextdata);
		}
	}

	
	
    return msg;
  }
}