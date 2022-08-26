#include "smartBracelet.h"
#include "Timer.h"
#include "printf.h"

module smartBraceletC{

	uses{

		//interfaces
		interface Boot;	
		
		interface AMSend;
		interface Receive;

		interface Random;
		interface SplitControl;

		interface Packet;
		interface PacketAcknowledgements;

		interface Leds;

		//timer pairing:
		interface Timer<TMilli> as TimerPairing;

		//timer transmitting: child transmission trigger: 10 seconds
		interface Timer<TMilli> as TimerTransmitting;

		//timer3: alarm after 60 seconds
		interface Timer<TMilli> as TimerAlert;
	}
}

implementation{

	//////////////////////////////////////////////////////////////////////////////
	//VARS

	//pre-installed keys
	uint16_t KeyParent[K_LEN]; //parent key
	uint16_t KeyChild[K_LEN]; //child key
	char ParentKey1[K_LEN] = "PLUTO12AGOSTO2022XXX";
	char ParentKey2[K_LEN] = "GASTONE12AGOSTO2022X";

	//unicast address (after a pairing)
	uint16_t UnicastPairingAddress; 

	//vars
	bool isPaired = FALSE;
	bool isParent = FALSE;
	bool AckParent = FALSE;

	//datagram
	message_t packet;

	//coordinates of the bracelets (last known from child)
	uint16_t coord_X;
	uint16_t coord_Y;

	//datagram counters
	uint8_t broadcastDatagramID=0;
	uint8_t infoDatagramID=0;

	//broadcast senders
	task void transmitBroadcastDatagram();
	task void transmitUnicastDatagram();
	task void transmitChildDatagram();

	//alarm senders
	task void alarmFalling();
	task void alarmMissing();

	////////////////////////////////BOOT/////////////////////////////////////////////
	
	event void Boot.booted(){
		//In this part the program generates all keys
		int i, n;
		dbg("node", "[info] Generating preloaded bracelets' keys..\n");
		for(n=1; n<=N_MAX; n++){			
			//if the node asigned from TOSSIM is the current
			if (TOS_NODE_ID == n){
				if((n % 2) == 1){
					//odd nodes assignment
					for (i=0; i<K_LEN; i++){
						KeyParent[i] = n;
						KeyChild[i] = n+1;
					}
					/*KeyParent = FOREACH_KEY[n]
					KeyChild = FOREACH_KEY[n+1]*/
					dbg("node", "[info] Node: %i | Key Parent: %ux%i | Key Child: %ux%i\n", n, KeyParent, K_LEN, KeyChild, K_LEN);
				}else{
					//even nodes assignment
					for (i=0; i<K_LEN; i++){
						KeyParent[i] = n;
						KeyChild[i] = n-1;
					}
					/*KeyParent = FOREACH_KEY[n]
					KeyChild = FOREACH_KEY[n+1]*/
					dbg("node", "[info] Node: %i | Key Parent: %ux%i | Key Child: %ux%i\n", n, KeyParent, K_LEN, KeyChild, K_LEN);
				}
			}
		}

		//bracelet type assignment
		if((TOS_NODE_ID % 2) == 1){
			//assign parent only if is odd
			isParent = TRUE;
			dbg("node", "[info] TOS_Node: %i is a PARENT\n", TOS_NODE_ID);
		}else{
			dbg("node", "[info] TOS_Node: %i is a CHILD\n", TOS_NODE_ID);
		}

		//starting radio
		call SplitControl.start();
	}

	//////////////////////////////////// TIMERS //////////////////////////////////////////

	//starting TimerPairing
	event void SplitControl.startDone(error_t error){
		if(error == SUCCESS) {
			dbg("radioTX", "[info] Starting Timer Pairing (every %i ms) for broadcast pairing at %s \n", T_1, sim_time_string());
			call TimerPairing.startPeriodic(T_1);
		}
		else{	
			dbg("node","[error] Radio starting error\n");
			call SplitControl.start();
		}
	}
	
	//Timer Pairing event (pairing)
	event void TimerPairing.fired(){
		dbg("radioTX", "[info] Timer Pairing fired at %s \n", sim_time_string());
		printf("The 2 Bracelet have been correctly paired, congratulation!!\n");
	  	printfflush();
		post transmitBroadcastDatagram();
	}

	//Timer Transmitting event (child)
	event void TimerTransmitting.fired(){
		printf("INFO message sent from the Child Bracelet\n");
	  	printfflush();
		dbg("radioTX", "[info] Timer Transmitting fired at %s \n", sim_time_string());
		call Leds.led0Off();
		call Leds.led1Off();
		post transmitChildDatagram();
	}

	//timer Alert event (alarm)
	event void TimerAlert.fired(){
		dbg("radioTX", "[info] Timer Alert fired at %s (missing messages from child in last %i ms) \n", sim_time_string(), T_3);
		call Leds.led0Off();
		call Leds.led1Off();
		call Leds.led2Off();
		post alarmMissing();
		printf("You child is out of range, PAY ATTENTION!!\n");
	  	printfflush();
	}


	////////////////////////////////////// TASKS ////////////////////////////////////////
	
	//broadcast transmitter for initial pairing phase
	task void transmitBroadcastDatagram() {
		
		//var allocation
		int i;

		if(!isPaired){

			//datagram initialization
			pairing_datagram_t* datagram = (pairing_datagram_t*)(call Packet.getPayload(&packet, sizeof(pairing_datagram_t)));
			
			//passing datagram id
			datagram->ID = broadcastDatagramID;
			broadcastDatagramID++;

			//passing datagram type
			datagram->type = BROADCAST;

			//passing key
			for (i=0; i<K_LEN; i++){
				datagram->key[i]= KeyParent[i];
			}

			//passing address
			datagram->address = TOS_NODE_ID;

			//log
			dbg("radioDatagram", "[radio>>] Broadcast datagram Id: %u is under transmission | Time: %s \n", datagram->ID,  sim_time_string());
		
			//transmission result
			if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(pairing_datagram_t)) == SUCCESS){
				//transmission success
				dbg("radioDatagram", "[radio>>] Broadcast datagram Id: %u | Transmission is OK | with content: \n", datagram->ID);
				dbg("radioDatagram", "\t Key: %ux%i \n", datagram->key, K_LEN);
				dbg("radioDatagram", "\t Address: %u \n", datagram->address);
				dbg("radioDatagram", "\t Type: %u \n", datagram->type);
			}
		}
	}

	//unicast transmitter for pairing phase
	task void transmitUnicastDatagram() {

		//datagram initialization
		pairing_datagram_ack_t* datagram = (pairing_datagram_ack_t*)(call Packet.getPayload(&packet, sizeof(pairing_datagram_ack_t)));

		//passing datagram type
		datagram->type = UNICAST;
		
		//passing datagram ack value (default ack = true)
		datagram->acknowledgement = 1;

		//log
		dbg("radioDatagram", "[radio>>] Unicast datagram (pairing acknowledgement) to Address: %u is under transmission | Time: %s \n", UnicastPairingAddress, sim_time_string());

		//enable ack listener
		AckParent = TRUE;

		//request an explicit ack for this transmission
		call PacketAcknowledgements.requestAck(&packet);

		//transmission result
		if(call AMSend.send(UnicastPairingAddress, &packet, sizeof(pairing_datagram_ack_t)) == SUCCESS){
			//transmission success
			dbg("radioDatagram", "[radio>>] Unicast datagram (pairing acknowledgement) to Address: %u | Transmission is OK | with content: \n", UnicastPairingAddress);
			dbg("radioDatagram", "\t Acknowledgement: %u \n", datagram->acknowledgement);
			dbg("radioDatagram", "\t Type: %u \n", datagram->type);
		}
	}


	//unicast transmitter for info datagrams (from child)
	task void transmitChildDatagram() {
	
		//datagram instantiation
		info_datagram_t* datagram = (info_datagram_t*)(call Packet.getPayload(&packet, sizeof(info_datagram_t)));
	
		//prepairing status
		int sendStatus;

		//random generator (1-10)
		uint16_t rnd = (call Random.rand16() % 10) + 1;

		// The probability of X, Y coordinates to be on standing, walking and running is of 30%, of falling is set to 10%, so:
		if(rnd>=1 && rnd<=3){
			
			//it is standing
			sendStatus = STANDING;

		}else if(rnd>=4 && rnd<=6){
			
			//it is walking
			sendStatus = WALKING;

		}else if(rnd>=7 && rnd<=9){
			
			//it is running
			sendStatus = RUNNING;

		}else if(rnd==10){
			
			//it is falling
			sendStatus = FALLING;

		}

		//log
		dbg("radioDatagram", "[radio>>] Random: %u | Random Status %i\n", rnd, sendStatus);

		//parameters assignment
		datagram->type = INFO;
		datagram->posX = call Random.rand16(); // We need it if we don't use Cooja in the simulation
		datagram->posY = call Random.rand16();
		datagram->status = sendStatus;
		datagram->ID = infoDatagramID;

		//log
		dbg("radioDatagram", "[radio>>] Child Unicast datagram Id: %u is under transmission | Time: %s \n", datagram->ID,  sim_time_string());

		//transmission result
		if(call AMSend.send(UnicastPairingAddress, &packet, sizeof(info_datagram_t)) == SUCCESS){
			//transmission success
			dbg("radioDatagram", "[radio>>] Child Unicast datagram Id: %u | Transmission OK | with content: \n", datagram->ID);
			dbg("radioDatagram", "\t Status: %i \n", datagram->status);
			dbg("radioDatagram", "\t Position X (Longitude): %u \n", datagram->posX);
			dbg("radioDatagram", "\t Position Y (Latitude): %u \n", datagram->posY);
		}
		//increasing id counter for next transmission 
		infoDatagramID++;
	}

	//task called in case of a falling alarm detected in child message
	task void alarmFalling(){

		//log
		dbg("radioDatagram", "[radio>>] !FALLING ALARM! received from child | Address: %u | Position X: %u / Position Y: %u \n", UnicastPairingAddress, coord_X, coord_Y);

		//led blinking
		call Leds.led0Toggle();
	}

	//task called in case of a missing alarm detected in child transmission
	task void alarmMissing(){

		//log
		dbg("radioDatagram", "[radio>>] !MISSING ALARM! received from child | Address: %u | Position X: %u / Position Y: %u \n", UnicastPairingAddress, coord_X, coord_Y);

		//led blinking
		call Leds.led0Toggle();
		call Leds.led1Toggle();
		call Leds.led2Toggle();
	}

	///////////////////////////////////////EVENTS//////////////////////////////////////////


	//stop radio event
	event void SplitControl.stopDone(error_t error){
		dbg("radioDatagram", "Error found! Stop the radio signal");
	}

	//send success event (for generic transmission)
	event void AMSend.sendDone(message_t *msg, error_t error){
	
		//if success
		if(&packet == msg && error == SUCCESS) {

			//only if the ack listener is set to true
			if(AckParent){ //acknowledgement received
				if(call PacketAcknowledgements.wasAcked(msg)) {

					//log
					dbg("radioDatagram", "[radio>>] The acknowledgment received at time %s \n", sim_time_string());

					//deactivate ack listener
					AckParent = FALSE;

				}else{

					//log
					dbg("radioDatagram", "[error] The acknowledgment was not received at time %s \n", sim_time_string());

					//retry to pair
					post transmitUnicastDatagram();
				}
			}
		}
	}

	//transmission incoming event
	event message_t * Receive.receive(message_t *msg, void *payload, uint8_t len){
	
		//var allocation
		int i;
		bool key_match = TRUE;

		//info - datagram instantiation
		info_datagram_t* info_dat = (info_datagram_t*)payload;

		//pairing - datagram instantiation
		pairing_datagram_t* pairing_dat = (pairing_datagram_t*)payload;

		//pairing ack - datagram instantiation
		pairing_datagram_ack_t* pairing_ack_dat = (pairing_datagram_ack_t*)payload;
		
		//type selector for BROADCAST
		if (pairing_dat->type == BROADCAST) {

			//log
			dbg("radioRX", "[radio<<] Incoming transmission from BROADCAST pairing datagram.\n");
			
			//checking the received key
			for (i=0; i<K_LEN; i++){
				if(pairing_dat->key[i] != KeyChild[i]){
					key_match = FALSE;
				}
			}

			//if the two keys matches 
			if(key_match){

				//saving pairing address
				dbg("radioRX","[radio<<] TOS_Node: %u has Key Parent: %ux%i | is paired | with TOS_Node: %u that has Key Child: %ux%i \n", TOS_NODE_ID, KeyParent, K_LEN, pairing_dat->address, pairing_dat->key, K_LEN);
				UnicastPairingAddress = pairing_dat->address;

				//calling unicast ack send
				dbg("radioRX","[radio>>] Sending UNICAST pairing confirmation.. \n");
				post transmitUnicastDatagram();

			}else{

				//keys does not match
				dbg("radioRX", "[radio<<] Datagram received from node %u has not the correct key\n", pairing_dat->address); 
			}
		}
		
		//type selector for UNICAST
		if (pairing_ack_dat->type == UNICAST) {

			//log
			dbg("radioRX", "[radio<<] Incoming transmission from UNICAST pairing datagram.\n");

			//checking the content (ack)
			if (pairing_ack_dat->acknowledgement == 1){

				//set bracelet as paired
				isPaired = TRUE;

				//led blinking
				call Leds.led2Toggle();

				//stopping broadcast transmission
				dbg("radioRX", "[radio<<] Pairing ACK received | is paired | Stopping broadcast transmission.. \n");
				call TimerPairing.stop();
	
				//starting operative timers
				if(isParent){

					//is parent, start alarm timer
					call TimerAlert.startPeriodic(T_3);

				}else{

					//is child, start info timer
					call TimerTransmitting.startPeriodic(T_2);
				}
			}
		}

		//if the bracelet is paired
		if(isPaired && isParent){

			//checking the content of the datagram
			if(info_dat->type == INFO){

				//led blinking
				call Leds.led1Toggle();

				//log
				dbg("radioRX", "[radio<<] Incoming transmission from UNICAST INFO datagram.\n");
				dbg("radioRX", "[radio<<] Child status: %u. \n", info_dat->status);

				//saving last coordinates
				coord_X = info_dat->posX;
				coord_Y = info_dat->posY;

				//restarting alarm timer
				call TimerAlert.stop();
				call TimerAlert.startPeriodic(T_3);

				//check if in a critical status
				if ((info_dat->status) == FALLING) {
					post alarmFalling();
				}
			}
		}

		//return
		return msg;
	}

}
