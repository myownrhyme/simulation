#ifndef PREAMBLETEST_H
#define PREAMBLETEST_H

enum {
  AM_BLINKTORADIO = 6,
  TIMER_PERIOD_MILLI = 250
};


typedef nx_struct Message
{
	nx_uint16_t nodeid;
	nx_uint16_t datatype;//1:preamble,2:preack,3:data,4:dataack,5:route
	nx_uint16_t level;//1-50 level1 ,51-150 level2 ,201-250 level3 ...
	nx_uint16_t counter;
	nx_uint16_t time;
	nx_uint16_t etx;
	nx_uint16_t data1;
	nx_uint16_t data2;
	nx_uint8_t remain;
}Message;




#endif
