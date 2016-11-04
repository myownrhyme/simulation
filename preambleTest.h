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
//控制包长度为17个2字节变量,前4个为固定位，后13个位自由段
//包固定位开始
	nx_uint16_t nodeid;//节点ID号
	nx_uint16_t flag;//标记位，控制包或者数据包，控制包为1，数据包为2，ACK包为3
	nx_uint16_t counter;//某节点发送数据包总数,即数据包批次号
	nx_uint16_t segment;//包分片号
//包固定位结束  
//包自由段开始

//数据包长度为12个2字节变量.
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


//最后1个1字节起填充作用
	nx_uint8_t remain;
//包自由段结束  
}Message;

//重命名
/*
typedef data1 	all_segment;//分片号总数
typedef data2	hop;//多跳跳步数
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
