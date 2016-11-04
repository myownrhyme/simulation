// $Id: BlinkToRadio.h,v 1.4 2006/12/12 18:22:52 vlahan Exp $

#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H
#include "sensors.h"
enum {
  AM_BLINKTORADIO = 6,
  TIMER_PERIOD_MILLI = 250
};


typedef nx_struct Message
{
//���ư�����Ϊ17��2�ֽڱ���,ǰ4��Ϊ�̶�λ����13��λ���ɶ�
//���̶�λ��ʼ
	nx_uint16_t nodeid;//�ڵ�ID��
	nx_uint16_t flag;//���λ�����ư��������ݰ������ư�Ϊ1�����ݰ�Ϊ2��ACK��Ϊ3
	nx_uint16_t counter;//ĳ�ڵ㷢�����ݰ�����,�����ݰ����κ�
	nx_uint16_t segment;//����Ƭ��
//���̶�λ����  
//�����ɶο�ʼ

//���ݰ�����Ϊ12��2�ֽڱ���.
	nx_uint16_t data1;
	nx_uint16_t data2;
	nx_uint16_t data3;
	nx_uint16_t data4;
	nx_uint16_t data5;
	nx_uint16_t data6;
	nx_uint16_t data7;
	nx_uint16_t data8;
	nx_uint16_t data9;
	nx_uint16_t data10;
	nx_uint16_t data11;
	nx_uint16_t data12;


//���1��1�ֽ����������
	nx_uint8_t remain;
//�����ɶν���  
}Message;

//������
/*
typedef data1 	all_segment;//��Ƭ������
typedef data2	hop;//����������
typedef data3	relay1;
typedef data4	relay2;
typedef data5	relay3;
typedef data6	relay4;
typedef data7	relay5;
typedef data8	remain1;
typedef data9	remain2;
typedef data10	remain3;
typedef data11	remain4;
typedef data12	remain5;
*/
#endif
