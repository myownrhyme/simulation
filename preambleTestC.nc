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
  
  uses interface Timer<TMilli> as nextSense;//��һ�����ݷ���
  uses interface Timer<TMilli> as waitforack;	//�ȴ�ACKʱ��
  
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
  bool IsRelay = FALSE; //�ж��Ƿ�ת�����ݰ�
  
  
  int data[TOTAL_SENSE_DATA];			//�ڵ�ɼ������ݺ󣬷ŵ����������
  bool senseDone[TOTAL_SENSE_TAG];
  //tempdata�����洢���յ�1��ת������������Ϣ
  //packetcounterΪ5�����ɻ��������Ϊ5��
  //packetlengthΪÿһ�����ĳ���Ϊ17��int�����ֽ�
  //���е�һ����Ϊ���ư�
  //����İ�Ϊ���ݰ�
  //���ư��� 1.ID,2.flag,3.counter,4.segment,5.all_segment,6.hop,7--11.relay,12-17.remain
  //���ݰ��� 1.ID,2.flag,3.counter.4.segment,5-16.data,17.remain
  //�������ݰ���data����,5.Voltage,6.Light,7.Temp,8.Humi,9.rssi,10--16 ����ʹ��
  int	tempdata[packetcounter][packetlength];  
  
  int	temp_i;
  int	temp_j;
  
  nx_uint16_t my_humi;
  nx_uint16_t my_temp;             //wrc-- 2011-1-11
  nx_uint16_t number;
  uint8_t i;                           //������ʼ�������ݵ�
  
  uint16_t datatype;//���������жϿ��ư������ݰ�
  
  uint16_t packetSegment;//������¼��Ƭ������
  uint16_t packetnumber;//���յ���ת�����ݰ�����
  int	packetID;//���յ���ת�����ݰ���ID
  int	packetCounter;//����ID�����ݰ��ĸ���
  int	segment;//�ְ���
  int	ack_receive;//�Ƿ���յ�ACK��0Ϊδ�յ���1Ϊ���յ���2Ϊδ����һ���ڵ㷵��ACK,3Ϊδ��ֵ״̬
  int	ack_target;//ACK���ص�Ŀ�Ľڵ�ID
  int	ack_number;//�ȴ�ACK���������ش��Ĵ���
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
  //datatype��ֵ����Ϊ0���Է��㣬����tempdata��ʹ��
  datatype=0;
  segment=1;//�ְ���
  
  
  //����level;
  if(TOS_NODE_ID>750 &&TOS_NODE_ID<760)
  {level = 1;}
  else  if(TOS_NODE_ID>760 &&TOS_NODE_ID<770)
  {level = 2;}
  else  if(TOS_NODE_ID>770 &&TOS_NODE_ID<780)
  {level = 3;}
  else  if(TOS_NODE_ID>780 &&TOS_NODE_ID<790)
  {level = 4;}
 
  
  
  //��ʼ����������ת����ز���
  InitialTemp();
  packetID=0;
  packetCounter=0;
  packetnumber=0;
  packetSegment=-1;
  
  //ACKδ��ֵ״̬
  ack_receive=3;
  ack_target=-1;//δ��ֵΪ-1
  ack_number=0;
  temp_receive=0;
  
   call AMControl.start();
  }
/*���ݽ���*/

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
  
//���������
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

	//ack_receiveΪ2��ʾ�����յ���һ���ڵ㷢�͵���Ϣ������δ����ACK��״̬
	if(ack_receive==2)
	{
	//ACK��ת������һ��ڵ�
	//�̶�λ��ֵ
		//ACK���ص�ID
		btrpkt->nodeid=TOS_NODE_ID;
		btrpkt->flag=3;//ACK��Ϊ3
		btrpkt->counter=0;
		btrpkt->segment=0;//��Ƭ��+1��ʾ��ȷ�����������ݰ�
	//���ɶθ�ֵ,ACKȫΪ0
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
	//ack_targetΪACK�ķ���Ŀ�Ľڵ�ID
	
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
			//akc_receiveΪ3����ʾACKδ��ֵ
			ack_receive=3;
			call Leds.led1Toggle();
		}
		//�ȷ���ACK������ת����Ϣ
		call nextSense.startOneShot(nextdata);
		return ;
	}
	
	
	//ת����
	if(TOS_NODE_ID!=0&&!busy && IsRelay==TRUE)
	{
	//ת������£��ȷ����ư����ٷ����ݰ�
	//datatype�������Ʒ��Ϳ��ư��������ݰ�
		if(datatype==0)
		{
		//���ư�ת��
		//�̶�λ��ֵ
			btrpkt->nodeid=tempdata[datatype][0];
			btrpkt->flag=tempdata[datatype][1];//���ư�1
			btrpkt->counter=tempdata[datatype][2];
			//ת��ʱsegment���Դ�tempdata�д�ȡ���˴�tempdata�޸ĺ�Ӧ���б仯
			btrpkt->segment=tempdata[datatype][3];
		//���ɶθ�ֵ
			
		//��Ҫ��ӷ�Ƭ��������ת����
			btrpkt->data1=tempdata[datatype][4];
			btrpkt->data2=tempdata[datatype][5];
			
			btrpkt->data3=tempdata[datatype][6];
			btrpkt->data4=tempdata[datatype][7];
			btrpkt->data5=tempdata[datatype][8];
			btrpkt->data6=tempdata[datatype][9];
			btrpkt->data7=tempdata[datatype][10];

		//Ԥ���ֶ�,�����ݶ�Ϊ0
			btrpkt->data8=level;
			btrpkt->data9=tempdata[datatype][12];
			btrpkt->data10=tempdata[datatype][13];
			btrpkt->data11=tempdata[datatype][14];
			btrpkt->data12=tempdata[datatype][15];
			btrpkt->remain=tempdata[datatype][16];
		}
		else
		{
		//���ݰ�����ת��
		//�̶�λ��ֵ
			btrpkt->nodeid=tempdata[datatype][0];
			btrpkt->flag=tempdata[datatype][1];//���ݰ�Ϊ2
			btrpkt->counter=tempdata[datatype][2];
			//ת��ʱsegment���Դ�tempdata�д�ȡ���˴�tempdata�޸ĺ�Ӧ���б仯
			btrpkt->segment=tempdata[datatype][3];
		//���ɶθ�ֵ
		//���ݰ����ɶ���Ҫ�����������ݵĴ���
		//Ŀǰ���Խ׶Σ�ʹ��7�����ݰ����������ݰ�Ϊ0
		//v,l,t,h,r
			btrpkt->data1=tempdata[datatype][4];
			btrpkt->data2=tempdata[datatype][5];
			btrpkt->data3=tempdata[datatype][6];
			btrpkt->data4=tempdata[datatype][7];
			btrpkt->data5=tempdata[datatype][8];
		
		//����7������λ,����Ϊ0
			btrpkt->data6=tempdata[datatype][9];
			btrpkt->data7=tempdata[datatype][10];
			btrpkt->data8=tempdata[datatype][11];
			btrpkt->data9=tempdata[datatype][12];
			btrpkt->data10=tempdata[datatype][13];
			btrpkt->data11=tempdata[datatype][14];
			btrpkt->data12=tempdata[datatype][15];
		//Ԥ���ֶ�
			btrpkt->remain=tempdata[datatype][16];
		}

		
	
	}
	//�Է���
	else if (TOS_NODE_ID!=0&&!busy &&IsRelay==FALSE) 
	{
		//�ȷ��Ϳ��ư�
		if(datatype==0)
		{
		//�̶��ֶθ�ֵ
			btrpkt->nodeid=TOS_NODE_ID;
			btrpkt->flag=1;//���ư�1
			btrpkt->counter=counter;
			btrpkt->segment=segment;
		
		//���ɶθ�ֵ
		//��Ҫ��ӷ�Ƭ���������Է���
		//Ŀǰ������Ҫ������Ϊ�ܷ�Ƭ��Ϊ2
			btrpkt->data1=2;	
			btrpkt->data2=0;
		
			
		
		//ĿǰΪ5��������tempdataҪ���д����޸�
			btrpkt->data3=0xffff;
			btrpkt->data4=0xffff;
			btrpkt->data5=0xffff;
			btrpkt->data6=0xffff;
			btrpkt->data7=0xffff;
		//Ԥ���ֶ�
			btrpkt->data8=level;//����level
			btrpkt->data9=0;
			btrpkt->data10=0;
			btrpkt->data11=0;
			btrpkt->data12=0;
			
			btrpkt->remain=0;
		}
		//���ŷ������ݰ�
		else
		{
		//�̶��ֶθ�ֵ
			btrpkt->nodeid=TOS_NODE_ID;
			btrpkt->flag=2;//���ݰ�Ϊ2
			btrpkt->counter=counter;
			//ת��ʱsegment���Դ�tempdata�д�ȡ���˴�tempdata�޸ĺ�Ӧ���б仯
			btrpkt->segment=segment;
		//���ɶθ�ֵ
		//���ݰ����ɶ���Ҫ�����������ݵĴ���
		//Ŀǰ���Խ׶Σ�ʹ��7�����ݰ����������ݰ�Ϊ0
			btrpkt->data1=1;
			btrpkt->data2=data[VOLTAGE_DATA];
			btrpkt->data3=data[LIGHT_DATA];
			btrpkt->data4=data[TEMP_DATA];
			btrpkt->data5=data[HUMI_DATA];
		
		//����7������λ
			btrpkt->data6=0;//rssiֵ
			btrpkt->data7=0;
			btrpkt->data8=0;
			btrpkt->data9=0;
			btrpkt->data10=0;
			btrpkt->data11=0;
			btrpkt->data12=0;
		//Ԥ���ֶ�
			btrpkt->remain=0;
		}
    }
	
	
	//������Ϣ����������������Ļ�����Ҫת������Ϣ
	//busy = TRUE;
	

	
	if (call AMSend.send(0xffff,&pkt, sizeof(Message)) == SUCCESS) 
	{
		
		//datatypeĿǰ��Ҫ�������Ʒ��Ϳ��ƺ����ݰ��ĸ���
		datatype++;
		//segment��������Ŀǰ��Ƭ���͵��ڼ���
		segment++;
		call Leds.led1Toggle();
	}


	
	//Ŀǰ����һ�����ư���һ�����ݰ����в��ԣ���2����
	if(datatype<2)
	{
		call nextSense.startOneShot(nextdata);
		//call Leds.led2Toggle();
	}
	else
	{
		datatype = 0;
		segment=1;//�ְ�
		
		//akc_receiveΪ0��ʾ���ڵȴ�ACK���أ�δ�յ�ACK״̬
		ack_receive=0;
		
		call waitforack.startOneShot(waitforack_time);//��ʼ�ȴ�ACK
		//call Leds.led0Toggle();
		
	}
  }
  

  //ACK�ȴ�
  event void waitforack.fired()//ACK���û�ڹ涨ʱ���ڷ��أ���ʼ�ش�
  {

	if(ack_receive==0 && ack_number<waitforack_number-1)	//���Դ��ڵȴ�ACK�׶�
	{
		ack_number++;
		busy=FALSE;
		SendMessage();				
	}
	else//�ɹ����յ�ACK�����ش���������
	{
		//������ͽ׶�Ϊת��������δ�յ�ACK��ת����־����
		//������ͽ׶�Ϊת���׶Σ����յ�ACK��ת����־�仯
		if(temp_receive==1)
		{
			temp_receive=0;
			//����ת��
			ack_receive=2;
			IsRelay=TRUE;//����ת����Ϣ
			call Leds.led2Toggle();//ת����   
			call nextSense.startOneShot(nextdata);
		}
		else
		{
			if(IsRelay == TRUE)
				IsRelay=FALSE;
			
			ack_receive=3;
			ack_number=0;
			//���������
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
		//������ȴ�ACK����
		
		
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
		//������ȴ�ACK����
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
  
 
//���ڽ��յ����ݰ���˵��RECEIVEֻ���д洢�������з��Ͳ���������ȫ����sendmessage
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
	
	
	Message* btrpkt=(Message*)payload;
	
	//MessageControl��MessageData���ݰ���ʽ��ͬ����������ͷ�ʽ��ͬ
    if (len < (sizeof(Message)+sizeof(uint16_t)) && len >(sizeof(Message)-sizeof(uint16_t)) ) 
	{	
		//btrpkt->flag==1Ϊ���ư�
        if (!busy && packetnumber==0 && btrpkt->flag==1 )                 
		{
			if(btrpkt->data8-level!=1)
			{
				return msg;
			}
		//���յ��ĵ�1����Ϊ���ư�
		//��ʱ�洢packet��ID��Counter���������жϺ������ݰ��Ƿ�Ϳ��ư�Ϊһ��
			packetID=btrpkt->nodeid;
			packetCounter=btrpkt->counter;
			//������ư������ݰ����ܸ���
			packetSegment=btrpkt->data1;
		
		//���ư��й̶�λ��ֵ
			//ID
			tempdata[packetnumber][0]=btrpkt->nodeid;
			//flag
			tempdata[packetnumber][1]=btrpkt->flag;
			//counter
			tempdata[packetnumber][2]=btrpkt->counter;
			//segment
			tempdata[packetnumber][3]=btrpkt->segment;
			
		//���ư������ɶθ�ֵ
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
		
		//btrpkt->flag==2Ϊ���ݰ�
		//packetnumber<packetSegment���Զ�̬�Ľ������ݰ��Ľ���
		if(!busy && packetnumber<packetSegment && btrpkt->flag==2 )
		{
			//�ӵ�2������ʼ�������ݰ��Ľ���
			if(packetID == btrpkt->nodeid && packetCounter == btrpkt->counter)
			{
				
			//���ݰ��й̶�λ��ֵ
				//ID
				tempdata[packetnumber][0]=btrpkt->nodeid;
				//flag
				tempdata[packetnumber][1]=btrpkt->flag;
				//counter
				tempdata[packetnumber][2]=btrpkt->counter;
				//segment
				tempdata[packetnumber][3]=btrpkt->segment;
			//���ݰ������ɶθ�ֵ	
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
				
			//���ݰ�����δʹ�õ����ݶ�
				tempdata[packetnumber][9]=btrpkt->data6;
				tempdata[packetnumber][10]=btrpkt->data7;
				tempdata[packetnumber][11]=btrpkt->data8;
				tempdata[packetnumber][12]=btrpkt->data9;
				tempdata[packetnumber][13]=btrpkt->data10;
				tempdata[packetnumber][14]=btrpkt->data11;
				tempdata[packetnumber][15]=btrpkt->data12;
				
			//���λ
				tempdata[packetnumber][16]=btrpkt->remain;
				
				packetnumber++;
			}
			else
			{
				//�ͷŻ�������packetID,packetCounter,packetnumber���
				InitialTemp();
				packetID=0;
				packetCounter=0;
				packetnumber=0;
				packetSegment=-1;
			}
		}
		
		
		
		
    }
	
	//����յ��İ�ΪACK��,��δ�յ�ACK
	if(!busy  && btrpkt->flag==3)
	{
		//ack_receiveΪ1����ʾ�ɹ�����һ���ڵ㷢�����ݵ�״̬
		
		ack_receive=1;
		ack_number=waitforack_number+1;
		
		call Leds.led0Toggle();//�յ�ACK 
	}
	
	if(!busy && packetnumber==packetSegment )
	{
		//����sendmessage��������Ϣת��
		
		//ack_receiveΪ2��ʾ�����յ���һ���ڵ㷢�͵���Ϣ������Ϊ����ACK��״̬
		
		
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
			IsRelay=TRUE;//����ת����Ϣ
			call Leds.led2Toggle();//ת����   
			call nextSense.startOneShot(nextdata);
		}
	}

	
	
    return msg;
  }
}