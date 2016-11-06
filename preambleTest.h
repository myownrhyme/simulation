#ifndef PREAMBLETEST_H
#define PREAMBLETEST_H

enum {
  AM_BLINKTORADIO = 6,
  TIMER_PERIOD_MILLI = 250
};


typedef nx_struct PreambleMessage
{

	nx_uint16_t nodeid;
	nx_uint16_t flag;
	nx_uint16_t counter;
	nx_uint8_t remain;
}PreambleMessage;

typedef nx_struct DataMessage
{

	nx_uint16_t nodeid;
	nx_uint16_t flag;
	nx_uint16_t counter;
	nx_uint8_t remain; 
}DataMessage;


#endif
