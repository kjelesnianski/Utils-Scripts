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
# About counting occurance: https://stackoverflow.com/questions/8969879/count-the-occurrence-of-a-string-in-an-input-file
# About variable recycling: https://unix.stackexchange.com/questions/312280/split-string-by-delimiter-and-get-n-th-element
#
#
#
#
# gnuplot needs file in form of (Ordered by occurance, most to least)
# [ Entry# LibName Occurances OrigFileSize ]
# To then update the dat file to be
# [ Entry# LibName Occurance OrigFileSize MarduFileSize MemSavings ]
# where MemSavings = (OrigFileSize*OCcurance)-MarduFileSize
#
# NOTE: NOT ALL LEA instructions use %RIP!!!! Those are NOT PC-relative!
#
#
# Author: K Jski
# Email : kjski@vt.edu
# Date  : 6/10/21
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
#PC_REL_COUNTER - pc-relative instruction counter (instructions using %rip)
P_COUNTER=0;
L_COUNTER=0;
F_COUNTER=0; 
C_COUNTER=0;
PC_REL_COUNTER=0;

L_COUNTER=$(cat $TPATH/systemd-libs.txt | wc -l)
echo "systemd Num Libs:$L_COUNTER"
echo ""

echo "------- PART 1A systemd counters"
systemd_arary=(`cat $TPATH/systemd-libs.txt`)
for i in "${systemd_arary[@]}"
do
	# Print the LIB name
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

	# Part 3 - PC relative asm counter
	CURR_PCR_COUNTER=$(objdump -d $i | awk '/%rip/' | wc -l)
	PC_REL_COUNTER=$(($PC_REL_COUNTER + $CURR_PCR_COUNTER))
	# Part 3A - LEA only asm counter
	#LEA_COUNTER=0;
	#CURR_LEA_COUNTER=$(objdump -d $i | awk '/lea  /' | wc -l)
	#LEA_COUNTER=$(($LEA_COUNTER + $CURR_LEA_COUNTER))
done

echo "Total Library  Count:$L_COUNTER"
echo "Total Function Count:$F_COUNTER"
echo "Total Callsite Count:$C_COUNTER"
echo "Total PC Relative Instr Count:$PC_REL_COUNTER"
#echo "Total LEA Instr Count        :$LEA_COUNTER"
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
PC_REL_COUNTER=0;

#echo "Pcount:$P_COUNTER"
#echo "Lcount:$L_COUNTER"
#echo "Fcount:$F_COUNTER"
#echo "Ccount:$C_COUNTER"
#echo "Ccount:$PC_REL_COUNTER"

# Go to /proc directory
cd /proc ;
# Find all directorys of depth 1
# | that are a number
{
find -maxdepth 1 | awk '/[0-9]$/' | tee $TPATH/allPID.txt
} &> /dev/null
echo "- Got all PID"

PID_W_LIB_COUNT=0;
LIB_COUNT=0;

# For each PID
ARRAY=(`cat $TPATH/allPID.txt`)
for i in "${ARRAY[@]}"
do
	# echo th PID
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


	CURR_PID_W_LIB=$(cat $i/maps | cut -d' ' -f 26 | awk NF | grep "\.so" | awk '!seen[$0]++' \
		| wc -l)

	if [[ $CURR_PID_W_LIB -gt 0 ]]
	then
		echo $i; 
		echo "LIBS with this PID:$CURR_PID_W_LIB"
		LIB_COUNT=$(( $LIB_COUNT + $CURR_PID_W_LIB ))
		PID_W_LIB_COUNT=$(( $PID_W_LIB_COUNT + 1 ))
	fi

	#echo the PID executable name
	CURR_PID_BIN_NAME=$(readlink $i/exe)
	if [[ ! -z "$CURR_PID_BIN_NAME" ]]
	then
		echo "PID BINARY $CURR_PID_BIN_NAME"
	fi

done

echo "Total number of Libs attached to PIDs	:$LIB_COUNT"
echo "Number of PIDs with LIBS			:$PID_W_LIB_COUNT"
echo ""
echo "- Got all unique LIB per PID"



echo "-------------------"
echo "--- Specific Library statistics"
# [ Entry# Occurances LibName OrigFileSize ]

# Step 1
# Records occurance of each lib
#END{ for ( name in count ) { print name " appears " count[ name ] " times" };
{
awk 'NF{ count[ $0 ]++}
    END{ for ( name in count ) { print count[ name ] " " name };
}' $TPATH/allLIBS.txt | sort -r -n | tee $TPATH/lib_occurance.txt
} &> /dev/null
# [ Occurance LibName ] 

# Step 2
# Overwrites with Additional FileSize info
S2=(`cat $TPATH/lib_occurance.txt`)

C=0
cat $TPATH/lib_occurance.txt | while read l
do
	CURR_LIB_O="$( cut -d' ' -f 1 <<< "$l" )"
	#echo "Occur:$CURR_LIB_O"

	CURR_LIB_N="$( cut -d' ' -f 2 <<< "$l" )"
	#echo "Name:$CURR_LIB_N"

	CURR_LIB_S=$( ls -l $CURR_LIB_N | cut -d' ' -f 5)
	echo "Vanilla Size(b):$CURR_LIB_S"
	CURR_LIB_S_KB=$(echo $CURR_LIB_S / 1000 | bc )
	#echo "Vanilla Size(Kb):$CURR_LIB_S_KB"

	# Now produces Kb size of lib
	# Megabyte is too small for Bash math (reduces to 0)
	CURR_MARDU_LIB_S=$(echo 1.66*$CURR_LIB_S | bc )
	echo "Mardu Size(b):$CURR_MARDU_LIB_S"
	CURR_MARDU_LIB_S_KB=$(echo $CURR_MARDU_LIB_S / 1000 | bc )
	#echo "Mardu Size(Kb):$CURR_MARDU_LIB_S_KB"

	CURR_NO_SHARE_LIB_S=$(( $CURR_LIB_S * $CURR_LIB_O ))
	echo "NoShare Size(b):$CURR_NO_SHARE_LIB_S"
	CURR_NO_SHARE_LIB_S_KB=$(( $CURR_NO_SHARE_LIB_S / 1000))
	#echo "NoShare Size(Kb):$CURR_NO_SHARE_LIB_S_KB"
	
	CURR_SAVINGS_S=$(echo $CURR_NO_SHARE_LIB_S_KB - $CURR_MARDU_LIB_S_KB | bc )

	echo "$C $CURR_LIB_O $CURR_LIB_N $CURR_LIB_S $CURR_MARDU_LIB_S_KB $CURR_NO_SHARE_LIB_S_KB $CURR_SAVINGS_S" \
	       | tee -a $TPATH/lib_usage_cdf.dat 

	C=$(( $C + 1 ))
done
# [ Occurance LibName OrigFileSize MarduFileSize MemSavings ]
# MemSavings = (OrigFileSize*OCcurance)-MarduFileSize


# [ Entry# Occurance LibName OrigFileSize MarduFileSize MemSavings ]





# Perform math of memory usage
TOTAL_NO_SHARE_MEM_USAGE=0;
TOTAL_SHARE_SIZE=0;
TOTAL_GOOSE_SIZE=0;

LIB_O=(`cat $TPATH/lib_occurance.txt`)
cat $TPATH/lib_occurance.txt | while read l
do
	#Extract Info
	#echo "LINE:$l"

	#Get library path
	LIB_N="$( cut -d' ' -f 2 <<< "$l" )"
	
	#Get # of usagges across all process
	OCCUR="$( cut -d' ' -f 1 <<< "$l" )"

	#get Library size
	CURR_LIB_SZ=$( ls -l $LIB_N | cut -d' ' -f 5)
	#echo "LIB[$LIB_N] C[$OCCUR] SZ[$CURR_LIB_SZ]"

	#Perform math
	#CURR_G_SZ=$(echo 1.66*$CURR_LIB_SZ | bc )
	#TOTAL_GOOSE_SIZE=$(echo $TOTAL_GOOSE_SIZE+$CURR_G_SZ  | bc )

	TOTAL_SHARE_SIZE=$(( $TOTAL_SHARE_SIZE + $CURR_LIB_SZ ))
	#echo "TOTAL_SHARE_SIZE:		$TOTAL_SHARE_SIZE"

	CURR_NO_SHARE=$(( $CURR_LIB_SZ * $OCCUR ))
	#echo "CURR NO SHARE:$CURR_NO_SHARE"

	TOTAL_NO_SHARE_MEM_USAGE=$(( $TOTAL_NO_SHARE_MEM_USAGE + $CURR_NO_SHARE ))
	#echo "TOTAL CURR NO SHARE:	$TOTAL_NO_SHARE_MEM_USAGE"
done
# IT SEEMS THAT WHILE LOOP MAKES BASH VARIABLES LOCAL AND DOES NOT UPDATE OUTSIDE OF LOOP
# LIKE FOR-LOOP

#echo "---- FINAL TALLY---"
#echo "Total MEM_USAGE NO SHARING:$TOTAL_NO_SHARE_MEM_USAGE"
#echo "Total Vanilla Shared Size :$TOTAL_SHARE_SIZE"
#echo "Total Goose Shared Size   :$TOTAL_SHAR_SIZE"
#echo "Total Memory Savings      :$MEM_SAVINGS"
echo "-------------------"

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

	# Part 3 - PC relative asm counter
	CURR_PCR_COUNTER=$(objdump -d $i | awk '/%rip/' | wc -l)
	PC_REL_COUNTER=$(($PC_REL_COUNTER + $CURR_PCR_COUNTER))
done

P_COUNTER=$(cat $TPATH/allPID.txt | wc -l)
L_COUNTER=$(cat $TPATH/allLIBS_2.txt | wc -l)
echo "Total Process  Count:$P_COUNTER"
echo "Total Library  Count:$L_COUNTER"
echo "Total Function Count:$F_COUNTER"
echo "Total Callsite Count:$C_COUNTER"
echo "Total PC Relative Instr Count:$PC_REL_COUNTER"

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
