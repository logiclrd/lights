#!/bin/bash

pin=$(cat /lights/pins/$1)

echo Initializing relay \#$1 =\> GPIO pin is $pin

echo $pin > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio$pin/direction
echo 1 > /sys/class/gpio/gpio$pin/value
chmod a+w /sys/class/gpio/gpio$pin/value


