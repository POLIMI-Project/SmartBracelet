#include "smartBracelet.h"
#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration smartBraceletAppC {}

implementation {

	////////////////Components/////////////////////////

	//Main
	components MainC, smartBraceletC as App;
	components new AMSenderC(AM_DATAGRAM);
	components new AMReceiverC(AM_DATAGRAM);
	components ActiveMessageC;
	components RandomC;

	//Timers
	components new TimerMilliC() as TimerPairing;
	components new TimerMilliC() as TimerTransmitting;
	components new TimerMilliC() as TimerAlert;
	
	//Various
	components LedsC;

	//Prints - used for Debug and Node-Red
	//components PrintfC;
    components SerialStartC;
	components SerialPrintfC;
	components SerialActiveMessageC as SAM;
	
	/////////////////////////////////////////////////////////
	//Interfaces

	//Boot
	App.Boot -> MainC.Boot;

	//Transmitter
	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;
	App.SplitControl -> ActiveMessageC;

	//Datagrams
	App.Packet -> AMSenderC;
	App.PacketAcknowledgements->ActiveMessageC;

	//Timers
	App.TimerPairing -> TimerPairing;
	App.TimerTransmitting -> TimerTransmitting;
	App.TimerAlert -> TimerAlert;

	//Random
	App.Random -> RandomC;

	//Leds
	App.Leds-> LedsC;
	
}
