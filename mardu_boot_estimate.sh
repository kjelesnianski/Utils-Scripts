#####################################################################
# Desc: Script that estimates boot time overhead for a vanilla system
# Version 0: Only grab libraries from process 1, systemd (the system
# 	init process)
# Version 1: Grab all libraries from all active processes on vanilla
#	machine
#
# NOTE: This script MUST be run with sudo (some operations require
# sudo)
# How to use cut https://stackabuse.com/substrings-in-bash/
# How to use find https://www.cyberciti.biz/faq/bash-foreach-loop-examples-for-linux-unix/
# https://stackoverflow.com/questions/971162/how-to-initialize-a-bash-array-with-output-piped-from-another-command/34224575
# Remove dup lines: https://unix.stackexchange.com/questions/30173/how-to-remove-duplicate-lines-inside-a-text-file
# about uniq command: https://www.howtoforge.com/linux-uniq-command/
# About delete specific lines: https://stackoverflow.com/questions/5410757/how-to-delete-from-a-text-file-all-lines-that-contain-a-specific-string
# About saving terminal line output: https://askubuntu.com/questions/420981/how-do-i-save-terminal-output-to-a-file
# About making block comment: https://stackoverflow.com/questions/947897/block-comments-in-a-shell-script
# About doing math in bash: https://unix.stackexchange.com/questions/55069/how-to-add-arithmetic-variables-in-a-scripit
#
#
#
#

# Author: K Jski
# Email : kjski@vt.edu
# Date  : 2/25/21
#####################################################################
#!/bin/bash
TPATH=/home/kjelesnianski/Utils-Scripts

### For ONLY STARTUP INIT PROCESS 'systemd'
# Go to /proc directory
echo "------- PART 1 systemd profiling"
cd /proc
# Go to startup init process
cd 1/
# Print maps
# | split line into array and return 26 element
# | remove blank lines
# | get only .so file names AKA shared libs
# | sort|uniq remove duplicates
# | write current output to file
# Includes the systemd process
{
cat maps | cut -d' ' -f 26 | awk NF | grep "\.so" | sort | uniq \
	| tee $TPATH/systemd-libs.txt
} &> /dev/null

#P_counter - process counter
#L_counter - library counter
#F_counter - function counter
#C_counter - callsite counter
P_COUNTER=0;
L_COUNTER=0;
F_COUNTER=0; 
C_COUNTER=0;

L_COUNTER=$(cat $TPATH/systemd-libs.txt | wc -l)
echo "systemd Num Libs:$L_COUNTER"
echo ""

echo "------- PART 1A systemd counters"
systemd_arary=(`cat $TPATH/systemd-libs.txt`)
for i in "${systemd_arary[@]}"
do
	# echo the LIB name
	#echo $i ;

	# PART 1
	# Derive number of FUNC symbols (remove UNDEFINED symbols)
	# Get readelf dump
	# | get only FUNC, GLOBAL symbols
	# | count how many symbols, 
	# save to variable
	CURR_F_COUNT=$(readelf -s $i | awk '/FUNC/' | grep -v "UND" | wc -l)
	#echo "CUR LIB F:$CURR_F_COUNT"
	# Add symbol count to running counter
	F_COUNTER=$(($F_COUNTER + $CURR_F_COUNT))
	#echo "UPDATE:$F_COUNTER"

	# PART 2
        # - At same time get number of call asm per library
	# objdump -d
	# | get only lines with 'callq'
	# | count lines
	# | save to variable 
	CURR_C_COUNTER=$(objdump -d $i | awk '/callq/' | wc -l)
	# add to running counter
	C_COUNTER=$(($C_COUNTER + $CURR_C_COUNTER))
done

echo "Total Library  Count:$L_COUNTER"
echo "Total Function Count:$F_COUNTER"
echo "Total Callsite Count:$C_COUNTER"
echo "------- PART 1A END"


#--------------------------------------------------------------------
#--------------------------------------------------------------------
#--------------------------------------------------------------------
#--------------------------------------------------------------------
### For ALL processes current active on machine
#--------------------------------------------------------------------

echo "------- PART 2 Idle system profiling"

P_COUNTER=0;
L_COUNTER=0;
F_COUNTER=0; 
C_COUNTER=0;

echo "Pcount:$P_COUNTER"
echo "Lcount:$L_COUNTER"
echo "Fcount:$F_COUNTER"
echo "Ccount:$C_COUNTER"

# Go to /proc directory
cd /proc ;
# Find all directorys of depth 1
# | that are a number
#ARRAY=('find -maxdepth 1 | awk '/[0-9]$/' ')
{
find -maxdepth 1 | awk '/[0-9]$/' | tee $TPATH/allPID.txt
} &> /dev/null
echo "- Got all PID"

# For each PID
ARRAY=(`cat $TPATH/allPID.txt`)
for i in "${ARRAY[@]}"
do
	# echo th PID
	# echo $i ;
	# Debug to see libs per PID
	#echo $i | tee -a /home/kjelesnianski/util_scripts/allLIBS.txt ;
	# Print PID/maps 
	# | only take library names 
	# | remove blank lines 
	# | remove dup 
	# | tee APPEND to allLIBS.txt
	{
	cat $i/maps | cut -d' ' -f 26 | awk NF | grep "\.so" | awk '!seen[$0]++' \
		| tee -a $TPATH/allLIBS.txt
	} &> /dev/null
done
echo "- Got all unique LIB per PID"

# Trim Lib file some more
# cat Open allLIBS file
# | awk get subset and remove non-'/usr/lib64/' filenames
# | awk remove duplicates
# | tee write to allLIBS_2.txt
{
cat $TPATH/allLIBS.txt | awk '!seen[$0]++' \
	| tee $TPATH/allLIBS_2.txt
} &> /dev/null
# Result is ALL unique libraries used by 'idle' system
echo "- Got all unique LIB"

# Below is pseudo block comment START
#: <<'END'

UNIQUE_LIBS=(`cat $TPATH/allLIBS_2.txt`)
for i in "${UNIQUE_LIBS[@]}"
do
	# echo the LIB name
	#echo $i ;

	# PART 1
	# Derive number of FUNC symbols (remove UNDEFINED symbols)
	# Get readelf dump
	# | get only FUNC, GLOBAL symbols
	# | count how many symbols, 
	# save to variable
	CURR_F_COUNT=$(readelf -s $i | awk '/FUNC/' | grep -v "UND" | wc -l)
	#echo "CUR LIB F:$CURR_F_COUNT"
	# Add symbol count to running counter
	F_COUNTER=$(($F_COUNTER + $CURR_F_COUNT))
	#echo "UPDATE:$F_COUNTER"

	# PART 2
        # - At same time get number of call asm per library
	# objdump -d
	# | get only lines with 'callq'
	# | count lines
	# | save to variable 
	CURR_C_COUNTER=$(objdump -d $i | awk '/callq/' | wc -l)
	# add to running counter
	C_COUNTER=$(($C_COUNTER + $CURR_C_COUNTER))
done

P_COUNTER=$(cat $TPATH/allPID.txt | wc -l)
L_COUNTER=$(cat $TPATH/allLIBS_2.txt | wc -l)
echo "Total Process  Count:$P_COUNTER"
echo "Total Library  Count:$L_COUNTER"
echo "Total Function Count:$F_COUNTER"
echo "Total Callsite Count:$C_COUNTER"

# Below is pseudo block comment END
#END

echo "------- PART 2A Idle system profiling - memory savings"
MEM_COUNTER=0;

UNIQUE_LIBS=(`cat $TPATH/allLIBS_2.txt`)
for i in "${UNIQUE_LIBS[@]}"
do
	#echo Lib name
	#echo $i;
	#Get element 5 for file size
	{
	CURR_MEM_SIZE=$(ls -l $i | cut -d' ' -f 5)
	} &> /dev/null

	MEM_COUNTER=$(($MEM_COUNTER + $CURR_MEM_SIZE))
done

echo "Total Size of all currently used Libs:$MEM_COUNTER"
