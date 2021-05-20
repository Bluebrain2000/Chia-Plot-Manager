# CONFIG ########################################################################################################
$plots=6;					# number of parallel plots
$maxInPhase1=3;		# max. number of concurrent plots in phase 1
$use_ram=6750;		# -b option (max RAM usage) for chia.exe
$use_threads=4;		# -r option for chia.exe
$drive_temp="G:\\Chia Plotting";	# -t option for chia.exe
$drive_final="F:\\Chia Staging";	# -d option for chia.exe
$sleeptime=30;		# sleep time in seconds between updates
$startNewPlot=1;	# if plotmanager should start new plots (normally=1, for debug purpose =0 to prevent the plotmanager to start new plots)
$check_last=6;		# number of last ... logfiles to parse for calculations
$send_data_to_server=0;	# submit status data to server?
$server_url="https://example.com/chiaplotlog.pl";
$stagedrive="F";
@farmingDrives=("I","J");
#################################################################################################################
