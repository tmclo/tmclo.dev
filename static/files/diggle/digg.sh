#!/bin/bash

[[ -z "$1" ]] && echo -e "\e[31mUsage:\e[0m $0 example.com" && exit

echo -e "\e[1m\e[31m---------------------------------------------\e[0m"
echo -e "\e[32m   checking dns for\e[34m" $1
echo -e "\e[1m\e[31m---------------------------------------------\e[0m"
while read p; do
	echo -e "\e[94m" $1 "\e[32m IN A       \e[35m" $p "\e[0m\e[95m " $(dig +short @1.1.1.1 -x $p) "\e[0m"
done < <(dig +short @1.1.1.1 in a $1)

while read p; do
	echo -e "\e[94m" $1 "\e[32m IN AAAA    \e[35m" $p "\e[0m\e[95m " $(dig +short @1.1.1.1 -x $p) "\e[0m"
done < <(dig +short @1.1.1.1 in aaaa $1)

while read p; do
	echo -e "\e[94m" $1 "\e[32m IN MX    \e[35m" $p "\e[0m"
done < <(dig +short @1.1.1.1 in mx $1)

while read p; do
	echo -e "\e[94m" $1 "\e[32m IN TXT     \e[35m" $p "\e[0m"
done < <(dig +short @1.1.1.1 in txt $1)

while read p; do
	echo -e "\e[94m" $1 "\e[32m IN SOA     \e[35m" $p "\e[0m"
done < <(dig +short @1.1.1.1 in soa $1)

echo -e "\e[1m\e[31m---------------------------------------------\e[0m"
echo -e "\e[1m\e[31m                 Name servers     \e[0m"
echo -e "\e[1m\e[31m---------------------------------------------\e[0m"
while read p; do
	echo -e "\e[1m\e[34m " $p "\e[0m\e[35m(\e[95m\e[1m"$(dig +short @1.1.1.1 $p)"\e[35m)\e[0m"
done < <(dig +short @1.1.1.1 ns $1 | sed 's/.$//')