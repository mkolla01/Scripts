#! /bin/bash

#
# The script is used to collect system configuration items (hardware, 
# OS, JVM) related with Cassandara operation and performance tuning. 
# Cassandra key configuration items like cassandra.yaml, cassandra-env.sh, ...
# are also collected.
#
# Once the script is executed successfully, a file named as 
# "cassys_info_<ip address>_yyyy-mm-dd.cfg" is generated in the same directory
# as where the script is executed. This file contains collected system 
# configuration items related with Cassandra, which contains the following
# main categories:
#
# - Basic Host Info
# - CPU Info 
# - Memory Info
# - Network Info
# - Resource Limit info
# - Cassandra HardDrvie Info
# - Cassandra JVM info
# - cassandra.yaml configuration
# - Basic Cassandra Cluster Status
#
#
# Usage: cassys_mc.sh [<cassandra config directory] 
#
# --------------------------------------------------
# Revision History
#    
#    version #        owner                date                Note    
#    0.5                MK            Feb. 26, 2016        Initial working version
#    0.6                MK            March 2, 2016        Add comment
#    1.0                MK            March 21, 2016        Improve check on RAID, Virtualization, and other minor updates
#

#CAS_CONFDIR_DFT=/opt/cassandra/conf
CAS_CONFDIR=$CAS_CONFDIR_DFT
if [[ ! -z "$1" ]]
then
   CAS_CONFDIR=$1
else
    echo "Please specify Cassandra configuration directory".
    echo "Usage: cassys_mc.sh [<cassandra config directory>]"
    exit
fi


now="$(date +'%Y-%m-%d_%H-%M-%S')"
now="$(date +'%Y-%m-%d')"
myip="$(hostname -i)"


CAS_YAML_FILE="$CAS_CONFDIR/cassandra.yaml"
CASSYS_CONF_FILENAME="cassys_info"
CASSYS_CONF_FILE="./${CASSYS_CONF_FILENAME}_$myip-${now}.cfg"
#CASSYS_ERR_FILE="./${CASSYS_CONF_FILENAME}_$myip-${now}.err"
CASSYS_ERR_FILE="$CASSYS_CONF_FILE"


if [[ ! -f $CAS_YAML_FILE ]]
then
    echo "Couldn't locate cassandra.yaml file. Please specify cassandra.yaml file directory location."
    echo "Usage:  cassys_mc.sh <cassandra.yaml directory>"
    echo
    exit
fi



echo "=== Collect Cassandra System Key Metrics ===="


echo "#" > $CASSYS_CONF_FILE 2> $CASSYS_ERR_FILE
echo "# Cassandra System Metric Collection" >> $CASSYS_CONF_FILE 
echo "# ----------------------------------" >> $CASSYS_CONF_FILE
echo -e "# Time:\t" `date` >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
echo -e "# Collector:\t" `whoami` >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
echo "#" >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


echo "... collecting basic host info"
echo "[Basic Host Info]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE
echo -e "hostname: \t" `hostname` >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
echo -e "ip addr: \t" "$myip" >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
echo >> $CASSYS_CONF_FILE
echo -n `java -version 2>> $CASSYS_CONF_FILE`
echo >> $CASSYS_CONF_FILE
echo -n `python -V 2>> $CASSYS_CONF_FILE`
echo >> $CASSYS_CONF_FILE

if [[ -f /etc/os-release ]]
then
   cat /etc/os-release >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
elif [[ -f /etc/redhat-release ]]
then
   cat /etc/redhat-release >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
else
   echo "Unsupported Linux OS yet..." >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
fi

echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


echo "... collecting virtualization info"
echo "[Virtualization Info]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE

virtualized=$(dmesg | grep -c virtual)
if [[ $virtualized -ne 0 ]]
then 
    echo "<<virtualized environment>>" >> $CASSYS_CONF_FILE
    
    dmidecode_loc="$(type -P dmidecode)"
    if [[ ! -z "$dmidecode_loc" ]]
    then
        dmidecode | egrep -i 'manufacturer|product' >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE    
    else
        dmesg | grep -i virtual >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
    fi
    
fi

echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


echo "... collecting CPU info"
echo "[CPU Info]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE

lscpu_loc="$(type -P lscpu)"
if [[ ! -z "$lscpu_loc" ]]
then
    lscpu >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
else
    echo "<<lscpu command is not available>>" >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
    echo >> $CASSYS_CONF_FILE
    cat /proc/cpuinfo >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
fi

echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


function print_osparm_value()
{
    if [[ -f "$1" ]]
    then
        cat "$1" >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
    else
        echo "N/A" >> $CASSYS_CONF_FILE
    fi
}

echo "... collecting Memory info"
echo "[Memory Info]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE
egrep 'Mem|Cache|Swap' /proc/meminfo >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
echo "-------------------" >> $CASSYS_CONF_FILE
for osvar in "max_map_count" "overcommit_memory" "overcommit_ratio" "swappiness" "zone_reclaim_mode"
do
    echo -ne "vm.$osvar:\t" >> $CASSYS_CONF_FILE
    print_osparm_value "/proc/sys/vm/$osvar"
done

echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


echo "... collecting Network info"
echo "[Networ Info]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE
for osvar in "rmem_max" "wmem_max"
do
    echo -ne "net.core.$osvar:\t" >> $CASSYS_CONF_FILE
    print_osparm_value "/proc/sys/net/core/$osvar"
done
for osvar in "tcp_rmem" "tcp_wmem" "tcp_keepalive_intvl" "tcp_keepalive_probes" "tcp_keepalive_time"
do
    echo -ne "net.ipv4.$osvar:\t" >> $CASSYS_CONF_FILE
    print_osparm_value "/proc/sys/net/ipv4/$osvar"
done

echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


echo "... collecting Resource Limit info"
echo "[Resource Limit info]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE
for osvar in "file-max" "file-nr"
do
    echo -ne "fs.$osvar:\t" >> $CASSYS_CONF_FILE
    print_osparm_value "/proc/sys/fs/$osvar"
done

echo "-------------------" >> $CASSYS_CONF_FILE
echo -ne "<<Resource limit configuration file: " >> $CASSYS_CONF_FILE

# find out the Cassandra user and PID
casuser=$(ps -ef | grep cassandra | grep -v bash | grep -v grep | awk '{print $1}')
caspid="$(ps auwx | grep cassandra | grep -v bash | grep -v grep | awk '{print $2}')"

if [[ "$casuser" =~ [0-9]+ ]]
then
    casuser_str=$(getent passwd $casuser | cut -d: -f1)
elif [[ "$casuser" =~ "cassand+" ]]
then
    casuser_str="cassandra"
else
    casuser_str=$casuser
fi


if [[ -f "/etc/security/limits.d/$casuser_str.conf" ]]
then
    echo "/etc/security/limits.d/$casuser_str.conf>>" >> $CASSYS_CONF_FILE
    echo >> $CASSYS_CONF_FILE
    cat "/etc/security/limits.d/$casuser_str.conf" >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
else
    echo "/etc/security/limits.conf>>" >> $CASSYS_CONF_FILE
    echo >> $CASSYS_CONF_FILE
    awk '!/^ *#/ && NF' "/etc/security/limits.conf" >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
fi

if [[ -f "/proc/$caspid/limits" ]]
then
    echo "-------------------" >> $CASSYS_CONF_FILE
    echo "<<Current resource limits for Cassandra process>> " >> $CASSYS_CONF_FILE
    echo >> $CASSYS_CONF_FILE
    cat /proc/$caspid/limits >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
fi


echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


#
# TODO: HardDrive Type (SSD vs HDD) check needs to be revisited
#    * rotational flag check in virtual environment does not work
#    * check whether physical or virtual environment
#    * Cassandra data directory device check, need to consider JBOD situation (multiple data diretories)
#    * No need to call print_harddrive_info() for each data directory; should call for each device
#
echo "... collecting Cassandra HardDrive info"
echo "[Cassandra HardDrvie Info]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE
function print_harddrive_info()
{
    device=$(df $1 | tail -1 | awk '{print $1}')
    echo "    Device name: $device"

    # the code snippet below does NOT work for RAID
    if [[ ! $device =~ "md" ]]
    then
        if [[ $virtualized -ne 0 ]] 
        then
            echo "    <<Virtualized Environment, \"rotational\" flag might not be accurate!>>"
        fi

        block_device=$(echo $device | awk -F '/' '{print $NF}' | sed -r 's/([0-9])+$//')
        echo -ne "    rotational\t"
        cat /sys/block/$block_device/queue/rotational
        echo -ne "    io scheduler\t"
        cat /sys/block/$block_device/queue/scheduler
        echo -ne "    read ahead (kb)\t"
        cat /sys/block/$block_device/queue/read_ahead_kb
    else
        echo "    (RAID detected, bypass...)" 
    fi
}

cas_datadir=$(awk 'c&&!--c;/data_file_directories:/{c=1}' $CAS_YAML_FILE | awk '{print $2}')
echo "Cassandra data directory: $cas_datadir" >> $CASSYS_CONF_FILE
print_harddrive_info $cas_datadir >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
echo >> $CASSYS_CONF_FILE

cas_commitlogdir=$(awk '/commitlog_directory:/' $CAS_YAML_FILE | awk -F ': ' '{print $2}')
echo "Cassandra commitlog directory: $cas_commitlogdir" >> $CASSYS_CONF_FILE
print_harddrive_info $cas_commitlogdir >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
echo >> $CASSYS_CONF_FILE

cas_savedcachesdir=$(awk '/saved_caches_directory:/' $CAS_YAML_FILE | awk -F ': ' '{print $2}')
echo "Cassandra saved_caches_directory: $cas_savedcachesdir" >> $CASSYS_CONF_FILE
print_harddrive_info $cas_savedcachesdir >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE

echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


echo "... collecting Cassandra JVM info"
echo "[Cassandra JVM info]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE
if [[ -z "$caspid" ]]
then
    echo "Cassandra is not running ..." >> $CASSYS_CONF_FILE
else
    echo "Cassandra PID:" >> $CASSYS_CONF_FILE
    echo "    $caspid" >> $CASSYS_CONF_FILE
    echo "Cassandra JVM Options:" >> $CASSYS_CONF_FILE
    ps auwx | grep -v grep | grep cassandra | awk '{for(i=12;i<=NF;++i)print "     "$i}' >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
fi

echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


echo "... collecting cassandra.yaml configuration items"
echo "[cassandra.yaml configuration]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE
awk '!/^ *#/ && NF' $CAS_YAML_FILE >> $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE

echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE


if [[ 0 -eq 1 ]]
then
echo "... collecting basic cluster status info"
echo "[Basic Cassandra Cluster Status]" >> $CASSYS_CONF_FILE
echo "---------------------------------" >> $CASSYS_CONF_FILE
echo -e "Cassandra" `nodetool version` >> $CASSYS_CONF_FILE
echo >> $CASSYS_CONF_FILE
nodetool describecluster >>  $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
echo >> $CASSYS_CONF_FILE
nodetool info >>  $CASSYS_CONF_FILE 2>> $CASSYS_ERR_FILE
fi


echo ">>> Done."
echo
