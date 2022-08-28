#ifndef SMART_BRACELET_H
#define SMART_BRACELET_H

//////////////////////////////////////////////
//GLOBAL VARS

//the max number of supported couples, where "total nodes = 2 couples = 4"
#define C_MAX 2
#define N_MAX C_MAX*2

//length of the keys
#define K_LEN 20

/*#define FOREACH_KEY(KEY) \
        KEY(04051998021208202200) \
        KEY(05199802199912082022) \
        KEY(19980219990412082022) \
        KEY(19021999059812082022) \
        KEY(PLUTO12AGOSTO2022XXX) \
        KEY(PIPPO12AGOSTO2022XXX) \
        KEY(GASTONE12AGOSTO2022X) \
        KEY(PAPERONE12AGOSTO2022) \*/ //Maybe it is better to random generate them


//timers values
#define T_1 12500 // Random, we didn't know how much was it
#define T_2 10000
#define T_3 60000


//////////////////////////////////////////////
//DATAGRAM TYPES

//datagram type
#define BROADCAST 0
#define UNICAST 1
#define INFO 2

//info datagram status code
#define STANDING 3
#define WALKING 4
#define RUNNING 5
#define FALLING 6

//////////////////////////////////////////////
//DATA STRUCTURES

//informative datagram (unicast)
typedef nx_struct info_datagram{
	nx_uint8_t type;
	nx_uint16_t posX;
	nx_uint16_t posY;
	nx_uint8_t status;
	nx_uint16_t ID;
} info_datagram_t;

//pairing datagram (broadcast)
typedef nx_struct pairing_datagram{
	nx_uint8_t type;
	nx_uint8_t key[K_LEN];
	nx_uint16_t address;
	nx_uint8_t ID;
}pairing_datagram_t;

//pairing acknowledgement datagram (unicast)
typedef nx_struct pairing_datagram_ack{
	nx_uint8_t type;
	nx_uint8_t acknowledgement;
}pairing_datagram_ack_t;

//datagram sender
enum{
	AM_DATAGRAM = N_MAX,
};

#endif
