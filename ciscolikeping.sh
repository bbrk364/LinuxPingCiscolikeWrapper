#!/bin/bash
#
# Cisco-like ping wrapper by Igor_Y
#
# Intended for Linux ping unility.
#
# BSD ping utility (like in FreeBSD, MAC OS X or other BSD-like systems) is
# supported partially:
# "Destination Host Unreachable", "Packet filtered", "Time to live exceeded",
# "Time to live exceeded", "Reply truncated" and "Source Quench" are not 
# supported because of multiline output.
# Some ping utilites may not be supported at all.
#
# Parsed ICMP messages:
#64 bytes from 192.168.248.51: icmp_seq=1 ttl=128 time=0.547 ms
#From 192.168.248.103 icmp_seq=1 Destination Host Unreachable
#From 172.24.0.134 icmp_seq=8 Packet filtered
#From 212.1.97.206 icmp_seq=1 Time to live exceeded
#Request timeout for icmp_seq 159	<-- This is from BSD
# Assuming that sequence counter is in sync
#From 192.168.0.52: icmp_seq=9 Source Quench
# Sequence counter is not in sync
#72 bytes from 172.26.22.10: icmp_seq=2 ttl=251 (truncated)
#From 10.0.0.4: icmp_seq=1 Redirect Host(New nexthop: 10.0.0.17)
#From 10.0.0.17: icmp_seq=2 Redirect Network(New nexthop: 10.0.0.23)
#From 195.137.185.66 icmp_seq=2 Frag needed and DF set (mtu = 1460)


#trap 'echo -e "\nCatched SIGINT"' SIGINT
trap '' SIGINT

n=1
count=1
err=""
param="$*"
numpackets=$(expr "$param" : '.*\s\?-c \{0,1\}\([0-9]*\).*')
deadline=$(expr "$param" : '.*\s\?-w \{0,1\}\([0-9]*\).*')
timeout=$(expr "$param" : '.*\s\?-t \{0,1\}\([0-9]*\).*')
showlegend=$(expr "$param" : '.*\s\?\(--show-legend\).*')		# 13
disablecounter=$(expr "$param" : '.*\s\?\(--disable-counter\).*')	# 17
wrap=$(expr "$param" : '.*\s\?--wrap=\([0-9]\+\).*')
neverending=$(expr "$param" : '.*\s\?\(--neverending\).*')		# 28
#echo "$showlegend, $disablecounter, $wrap, $neverending"
#echo "$param"

# Setting wrap dafault to 80 if not specified
if [[ "$wrap" == "" ]]; then wrap=80; fi
#echo "$wrap"
#echo ""

# Removing custom parameters from ping command input string
param=${param//--show-legend/}
param=${param//--disable-counter/}
param=${param//--wrap=$wrap/}
param=${param//--neverending/}

if [[ "$param" == "" ]]
  then
    echo "Additional parameters:"
    echo -e " --show-legend\t\t- Shows the legend before pinging."
    echo -e " --disable-counter\t- Disables counter at ping line wraps."
    echo -e " --wrap=XX\t\t- Set number of symbols to wrap ping lines after (default 80)."
    echo -e " --neverending\t\t- Set ping to wait for Ctrl+C instead of default 5 packets."
    echo ""
fi

if [[ "$showlegend" == "--show-legend" || "$param" == "" ]]
  then
    echo "Legend:"
    echo " ! - Reply recieved			. - Reply lost"
    echo " u - Destination Host Unreachable	f - Packet filtered"
    echo " < - Reply sequence from the past	x - Time to live exceeded"
    echo " t - Reply truncated			q - Source Quench"
    echo ""
fi

echo "numpackets=$numpackets, deadline=$deadline, timeout=$timeout"
if [[ "$numpackets" == "" && "$deadline" == "" && "$timeout" == "" && "$neverending" == "" && "$param" != "" ]]; then param="-c 5 ${param}"; fi

echo "ping $param"
echo "Start: " `date "+%H:%M:%S %d/%m/%Y"`
echo ""

while read line
do
# ICMP event detection
num=$(expr "$line" : '[0-9]\{1,\} bytes from .*: icmp_[rs]eq=\([0-9]\{1,\}\) ttl=[0-9]\{1,\} time=.*$')
unr=$(expr "$line" : 'From .* icmp_[rs]eq=\([0-9]\{1,\}\) Destination Host Unreachable$')
fil=$(expr "$line" : 'From .* icmp_[rs]eq=\([0-9]\{1,\}\) Packet filtered$')
ttl=$(expr "$line" : 'From .* icmp_[rs]eq=\([0-9]\{1,\}\) Time to live exceeded$')
tmo=$(expr "$line" : 'Request timeout for icmp_seq \([0-9]\{1,\}\)$')
# Assuming that sequence counter is in sync
qnc=$(expr "$line" : 'From .*: icmp_[rs]eq=\([0-9]\{1,\}\) Source Quench$')
# Sequence counter is not in sync
trc=$(expr "$line" : '[0-9]\{1,\} bytes from .*: icmp_[rs]eq=\([0-9]\{1,\}\) ttl=[0-9]\{1,\} (truncated)$')
hst=$(expr "$line" : 'From .*: icmp_[rs]eq=\([0-9]\{1,\}\) Redirect Host(New nexthop: .*)$')
net=$(expr "$line" : 'From .*: icmp_[rs]eq=\([0-9]\{1,\}\) Redirect Network(New nexthop: .*)$')
fra=$(expr "$line" : 'From .* icmp_[rs]eq=\([0-9]\{1,\}\) Frag needed and DF set (mtu = .*)$')

# Normal echo reply
if [[ "$num" ]]
  then
    if [[ "$num" -lt "$n" ]]
      then
	# This check is needed bacause on MAC OS X icmp sequence starts from 0 whereas on linux it starts from 1
	if [[ $num -eq 0 ]]
	  then
            n=$num
          else
            echo -n "<"
            n=$(( n - 1 ))
        fi
    fi
    if [[ "$num" -gt "$n" ]]
      then
        dif=$(( num - n ))	# let "dif=$num-$n"
        for ((a=1; a <= dif ; a++))
        do
          echo -n "."
          if (( count % $wrap == 0 ))
            then
              if [[ "$disablecounter" == "" ]]
                then
                  echo " $count"
                else
                  echo ""
              fi
          fi
          (( n++ ))
          (( count++ ))
        done
    fi
    if [[ "$num" -eq "$n" ]]
      then
        echo -n "!"
    fi
    if (( count % $wrap == 0 ))
      then
        if [[ "$disablecounter" == "" ]]
          then
            echo " $count"
          else
            echo ""
        fi
    fi
    (( n++ ))
    (( count++ ))
fi

# Destination unreachable
if [[ "$unr" ]]
  then
    if [[ "$unr" -gt "$n" ]]
      then
        dif=$(( unr - n ))	# let "dif=$unr-$n"
        for ((a=1; a <= dif ; a++))
        do
          echo -n "."
          if (( count % $wrap == 0 ))
            then
              if [[ "$disablecounter" == "" ]]
                then
                  echo " $count"
                else
                  echo ""
              fi
          fi
          (( n++ ))
          (( count++ ))
        done
    fi
    if [[ "$unr" -eq "$n" ]]
      then
        echo -n "u"
    fi
    if (( count % $wrap == 0 ))
      then
        if [[ "$disablecounter" == "" ]]
          then
            echo " $count"
          else
            echo ""
        fi
    fi
    (( n++ ))
    (( count++ ))
fi

# Packet filtered
if [[ "$fil" ]]
  then
    if [[ "$fil" -gt "$n" ]]
      then
        dif=$(( fil - n ))	# let "dif=$fil-$n"
        for ((a=1; a <= dif ; a++))
          do
            echo -n "."
            if (( count % $wrap == 0 ))
              then
                if [[ "$disablecounter" == "" ]]
                  then
                    echo " $count"
                  else
                    echo ""
                fi
            fi
            (( n++ ))
            (( count++ ))
          done
    fi
    if [[ "$fil" -eq "$n" ]]
      then
        echo -n "f"
    fi
    if (( count % $wrap == 0 ))
      then
        if [[ "$disablecounter" == "" ]]
          then
            echo " $count"
          else
            echo ""
        fi
    fi
    (( n++ ))
    (( count++ ))
fi

# Time to live exceeded
if [[ "$ttl" ]]
  then
    if [[ "$ttl" -gt "$n" ]]
      then
        dif=$(( ttl - n ))	# let "dif=$ttl-$n"
        for ((a=1; a <= dif ; a++))
          do
            echo -n "."
            if (( count % $wrap == 0 ))
              then
                if [[ "$disablecounter" == "" ]]
                  then
                    echo " $count"
                  else
                    echo ""
                fi
            fi
            (( n++ ))
            (( count++ ))
          done
    fi
    if [[ "$ttl" -eq "$n" ]]
      then
        echo -n "x"
    fi
    if (( count % $wrap == 0 ))
      then
        if [[ "$disablecounter" == "" ]]
          then
            echo " $count"
          else
            echo ""
        fi
    fi
    (( n++ ))
    (( count++ ))
fi

# Source Quench
if [[ "$qnc" ]]
  then
    if [[ "$qnc" -gt "$n" ]]
      then
        dif=$(( qnc - n ))	# let "dif=$qnc-$n"
        for ((a=1; a <= dif ; a++))
          do
            echo -n "."
            if (( count % $wrap == 0 ))
              then
                if [[ "$disablecounter" == "" ]]
                  then
                    echo " $count"
                  else
                    echo ""
                fi
            fi
            (( n++ ))
            (( count++ ))
          done
    fi
    if [[ "$qnc" -eq "$n" ]]
      then
        echo -n "q"
    fi
    if (( count % $wrap == 0 ))
      then
        if [[ "$disablecounter" == "" ]]
          then
            echo " $count"
          else
            echo ""
        fi
    fi
    (( n++ ))
    (( count++ ))
fi

# Some ICMP messages are being captured in "err" variabe.
if [[ "$hst" || "$net" || "$fra" || "$ttl" || "$trc" || "$qnc" ]]
  then
    if [[ "$err" ]]
      then
        err=$(echo -e "$err""\n$line")
      else
        err="$line"
    fi
fi

# Displaying any lines that do not match preassigned filters.
# And silently dropping some BSD ping messages "Request timeout for icmp_seq".
if [[ "$num" == "" && "$unr" == "" && "$fil" == "" && "$ttl" == "" && "$trc" == "" && \
      "$qnc" == "" && "$hst" == "" && "$net" == "" && "$fra" == "" && "$tmo" == "" ]]
  then echo "$line"
  #else
    # Debug output
    #echo " num=$num unr=$unr fil=$fil ttl=$ttl trc=$trc qnc=$qnc hst=$hst net=$net fra=$fra"
fi

# This is called "Process Substitution"
done < <(ping $param)

# Echo all unususl lines captured during ping session.
if [[ "$err" ]]
  then
    echo ""
    echo "ICMP messages:"
    echo "$err"
fi
echo ""
echo "Finish: " `date "+%H:%M:%S %d/%m/%Y"`
exit 0
