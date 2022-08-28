# SmartBracelet
In this repository we put all the code of the IoT project of the course of Politecnico di Milano about Smart Bracelet

In this Project we implemented a software using TinyOs and NodeRed.

This software is applied on smart bracelets, which are worn by children and their parents (2 couples), and help parents to keep track of the child's position. When the child goes beyond a communication ratio, an alert notifies the respective parent.

For the simulation we have used Cooja, making sure that every part of the code fulfills the project tasks. Each file making the simulation possible is explained below:

The first file which is important to be analyzed is smartBracelet.h. 

### smartBracelet.h
In this file we first defined all the constants, such the *number of possible connections*, the *length* of the *keys*, which is defined with a function which generates random integer number, the \textit{type} of the message (which can be BROADCAST [0], UNICAST [1] or for INFO [2]) and the timers.\\
Furthermore we have specified all the possible status code (that can be STANDING 3 WALKING 4 RUNNING 5 or FALLING 6) and the data structures, together with their components: 
