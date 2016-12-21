#!/usr/bin/env bash

S0=$(($RANDOM%256))
S1=$(($RANDOM%256))
S2=$(($RANDOM%256))

MAC=b8:27:eb:`printf '%02x:%02x:%02x' $S0 $S1 $S2`
SERIAL=0000000046`printf '%02x%02x%02x' $S0 $S1 $S2`

sed "{ s/@MAC@/$MAC/ 
       s/@SERIAL@/$SERIAL/ }" $1

