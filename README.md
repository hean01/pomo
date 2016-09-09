# pomo

_pomo_ is a small AVR project thats help you to manage the pomodore
method. [Pomodoro](https://en.wikipedia.org/wiki/Pomodoro_Technique)
is a time management method to increase mental agility.

The _pomo_ device can look like anything but will have 4 leds and 2
buttons to assist you with your time management. First button is a
power switch turning the device on and off. The second button is a
push button which will break out from a pause and start next pomodoro
timer or reset the device starting with a new pomodoro cycle.

The _pomo_ device is battery driven and there for we need a design to
extend the battery life. To minimize the current draw each led is
displayed @ 50fps and never at the same time. This leaves us with a
clock of the main program of 200fps eg. 5ms.


## building

To build the source you need following requirements: make, gnu avr
toolchain and avrdude.

To build the program just do:

    make

or if you have the _usbtiny_ programmer just do:

    make upload FILE="pomodoro.hex"

