# Chia Plotman
# v0.2 2021-05-18
# by Richard Mastny a.k.a. Bluebrain
# https://github.com/Bluebrain2000/Chia-Plot-Manager
# license: GPL
$|=1;
system("cls");
print "\e[?25l"; # hide the cursor

use Date::Calc qw(Today Today_and_Now Delta_DHMS Normalize_DHMS);
use Term::ANSIColor;
use LWP::Simple;
use Win32::DriveInfo;

# CONFIG ########################################################################################################
require "./plotman.conf.pl";
#################################################################################################################

# get directories 
$userprofile=$ENV{USERPROFILE};
print "userprofile: $userprofile\n";
foreach(<$userprofile\\AppData\\Local\\chia-blockchain\\app*>) {
	$chiaexepath=$_."\\resources\\app.asar.unpacked\\daemon";
}
if($chiaexepath=~/app-(.*?)\\/) {
	$chiaversion="app-".$1;
}
print "chiaexepath: $chiaexepath\n";
$logpath="$userprofile\\.chia\\mainnet\\plotter";
print "logpath:     $logpath\n";
print "chiaversion: $chiaversion\n";
print "\n";

# copy chia.exe to chia1.exe, chia2.exe, etc. if not already present
for(1..$plots) {
	if(!-e "$chiaexepath\\chia$_.exe") {
		system("copy $chiaexepath\\chia.exe $chiaexepath\\chia$_.exe");
	}
}

# optional start arguments for manual override
$startnew=1 if($ARGV[0] eq "new");	# force start of new plot
$age_unix_threshold_override=$ARGV[0] if($ARGV[0]=~/^\d+$/); # override time offset (only) for next plot start

&calculate_timings();
sleep(5);
($cpu,$totalMemory,$freeMemory)=&cpu_ram();

while(1) {
	undef $chias;
	undef @chia_pid;
	@chia_checkbox=(" ");
	for(1..$plots) {
		$chia_checkbox[$_]=" ";
	}
	$ret=`pslist.exe -nobanner chia`;
	foreach(split(/\n/,$ret)) {
		if($_=~/^chia(\d?)\s+(\d+)/) {
			$chia_pid[$1]=$2;
			$chia_checkbox[$1]="X";
			$chias++;
		}
	}
	system("cls");
	print color 'bright_white';
	print "chia.exe instances running: $chias ($chiaversion) $ppd ppd\n";
	for(1..$plots) {
		print " $_  ";
	}
	print "\n";
	for(1..$plots) {
		print "[".$chia_checkbox[$_]."] ";
	}
	print color 'white';
	print "\n\n";
	
	# CPU / RAM / Drivespace Display
	print color 'black on_white';
	print " CPU     RAM      ";
	print "Stage $stagedrive     ";
	foreach(@farmingDrives) {
		print "Farm $_     ";
	}
	print "\n";
	print color 'white on_black';
	
	for(1..(3-length($cpu))) { print " "; }
	print "$cpu%   ";
	
	for(1..(4-(length($totalMemory)+length($freeMemory)))) { print " "; }
	print "$freeMemory/$totalMemory GB   ";
	
	$free=(Win32::DriveInfo::DriveSpace($stagedrive))[6];
	$free_gb=sprintf('%.0f',$free/1024/1024/1024);
	print color 'green';
	print color 'bright_red' if($free_gb<220);
	print $free_gb." GB     ";
	for(1..(4-length($free_gb))) { print " "; }
	$free_stage=$free_gb;
	
	foreach(@farmingDrives) {
		$free=(Win32::DriveInfo::DriveSpace($_))[6];
		$free_gb=sprintf('%.0f',$free/1024/1024/1024);
		print color 'green';
		print color 'bright_red' if($free_gb<550);
		print $free_gb." GB    ";
		for(1..(4-length($free_gb))) { print " "; }
		$free_farm{$_}=$free_gb;
	}
	print "\n\n";

	for(1..4) {
		$inPhase[$_]=0;
	}
	$phase1_table=999;
	$age_unix_youngest=999999;

	# parse all log files
	foreach (<$logpath\\plot*.txt>) {
		@temp=split(/\\/,$_);
		$filename=$temp[-1];
		next if($ignore{$filename});
		
		if($filename=~/plot_q(\d)/) {
			$plotter_id=$1;
		}
		
		undef $progress;
		undef $finished;
		undef $first;
		undef $phase;
		undef $phase3_first_computation_pass;
		open(LOGFILE, "<$_");
		while(<LOGFILE>) {
			if(!$first) {
				$first=1;
				$age=0;
				$age_unix=999999;
				# 2021-05-02T08:57:22.029  chia.plotting.create_plots
				if($_=~/(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)\./) {
					($Dd,$Dh,$Dm,$Ds) = Delta_DHMS($1,$2,$3, $4,$5,$6, Today_and_Now());
					$age=$Dd*24 + $Dh + $Dm/60 + $Ds/3600;
					$age_unix=$Dd*24*3600 + $Dh*3600 + $Dm*60 + $Ds;
					$Ds="0".$Ds if($Ds<10);
					$Dm="0".$Dm if($Dm<10);
					$age_text=($Dd*24 + $Dh).":$Dm:$Ds";
				}
				last if(!$age || $age>$age_dead);
			}

			if($_=~/^ID: (.+)$/) {
				$id=$1;
			}

			if($id) {
				if($_=~/Starting phase (\d)\/4:/) {
					$phase=$1;
					undef $table;
					undef $bucket;
				}
				if($phase==1 && $_=~/Computing table (\d)/) {
					$table=$1;
				}
				if($phase==2 && $_=~/Backpropagating on table (\d)/) {
					$table=8-$1;
				}
				if($phase==2 && $_=~/table 1 new size:/) {
					$table=7;
				}
				if($phase==3 && $_=~/Compressing tables . and (\d)/) {
					$table=$1;
					$phase3_first_computation_pass=0;
				}
				# no tables in phase 4
				
				if($phase==3 && $_=~/First computation pass time/) {
					$phase3_first_computation_pass=1;
				}
				
				if($phase==1 && $table>1 && $_=~/Bucket (\d+) uniform sort/) {
					$bucket=$1;
				}
				# no buckets in phase 2
				if($phase==3 && $_=~/Bucket (\d+)/) {
					$bucket=$1;
				}

				if($phase==4 && $_=~/Bucket (\d+) uniform sort/) {
					$bucket=$1;
				}
			}
			
			if($_=~/^Total time = /) {
				$finished=1;
			}
		}
		close(LOGFILE);
		
		if(!$finished && $age<$age_dead) {
			$age_unix_youngest=$age_unix if($age_unix<$age_unix_youngest);
			$age[$plotter_id]=$age;
			if($phase==1 && $table<$phase1_table) {
				$phase1_table=$table;
				$phase1_bucket=$bucket;
			}
			
			# ignoring (fast) table 1, so table for calculation is $table-1, counting 1..6
			if($phase==1) {
				$tables_finished=$table-2;
				$tables_finished=0 if($tables_finished<0);
				$progress+=($ptu[$phase]/6*$tables_finished) + ($ptu[$phase]/6/128*($bucket+1));
			} elsif($phase>1) {
				$progress+=$ptu[1];
			}
			if($phase==2) {
				# no buckets in phase 2
				$progress+=($ptu[$phase]/6*($table-1));
			} elsif($phase>2) {
				$progress+=$ptu[2];
			}
			if($phase==3) {
				$progress+=($ptu[$phase]/12*($table-1)*($phase3_first_computation_pass+1));
			} elsif($phase>3) {
				$progress+=$ptu[3];
			}
			if($phase==4) {
				# no tables in phase 4
				$progress+=$ptu[$phase]/128*($bucket+1);
			}
			
			$proz[$plotter_id]=sprintf('%.0f',100/($ptu[1]+$ptu[2]+$ptu[3]+$ptu[4]+1)*$progress);

			print color 'bright_green';
			print "PLOTTER $plotter_id:";
			if($chia_pid[$plotter_id]) {
				print color 'white';
				print " PID $chia_pid[$plotter_id]";
			} else {
				print color 'bright_red';
				print " KILLED?!";
			}
			print color 'bright_white';
			print "\n[";
			for($i=1; $i<=100; $i+=2) {
				if($i<=$proz[$plotter_id]) {
					print "#";
				} else {
					print "_";
				}
			}
			print "] $proz[$plotter_id]%\n";
			print color 'white';
			print "ID $id\n";
			print "$filename\n";
			print "age: $age_text\n";
			print color 'bright_magenta';
			print "phase $phase";
			if($table) {
				print "   table $table/7";
			} else {
				print "            ";
			}
			if($bucket) {
				print "   bucket $bucket/128";
				if($phase==3 && !$phase3_first_computation_pass) {
					print " (1/2)";
				} elsif($phase==3 && $phase3_first_computation_pass) {
					print " (2/2)";
				}
			}
			print color 'reset';
			print "\n\n";
			$inPhase[$phase]++;
		} else {
			$ignore{$filename}=1;
		}
		$c++;
	}

	for(1..4) {
		print "in phase $_: $inPhase[$_] ";
		for(1..$inPhase[$_]) { print "#"; }
		print "\n";
	}
	print "youngest: $age_unix_youngest sec., threshold: $age_unix_threshold sec.\n";
	($Dd,$Dh,$Dm,$Ds) = Normalize_DHMS(0,0,0,$age_unix_threshold-$age_unix_youngest);
	$Dm="0".$Dm if($Dm<10);
	$Ds="0".$Ds if($Ds<10);
	if($age_unix_threshold-$age_unix_youngest < 0) {
		print "next start in: waiting for plot to finish\n";
	} else {
		print "next start in: $Dh"."h $Dm"."m $Ds"."s\n";
	}
	if(!$startNewPlot) {
		print color "bright_red";
		print "autostart not set\n";
		print color "white";
	}
	
	# start new plotter
	if($startnew || $startNewPlot && $chias<$plots && $inPhase[1]<$maxInPhase1 && ($age_unix_youngest==999999 || $age_unix_youngest>=$age_unix_threshold)) {
		$startnew=0;
		for(1..$plots) {
			if(!$chia_pid[$_]) {
				$plotter_id_new=$_;
				last;
			}
		}
		system("cls");
		print color 'bright_green';
		print "******************************\n";
		print "STARTING NEW PLOTTER WITH ID $plotter_id_new\n";
		print "******************************\n";
		print color 'reset';
		&calculate_timings();
		
		&date(time);
		$rand=1000000+int(rand(8999999));
		$logfilename="plot_q".$plotter_id_new."_$CCyear-$CCmon-$CCmday"."_$CChour-$CCmin-$CCsec"."_$rand.txt";
		$command="start /b $chiaexepath\\chia$plotter_id_new.exe plots create -b $use_ram -r $use_threads -t \"$drive_temp\" -d \"$drive_final\" -x 1>$logpath\\$logfilename 2>&1";
		print $command;
		system($command);
		sleep(9);
		($cpu,$totalMemory,$freeMemory)=&cpu_ram();	# takes ~1s
	} else {
		print color 'reset';
		if($send_data_to_server) {
			$chias_max=$chias if($chias>$chias_max);
			$data="pc=$ENV{COMPUTERNAME}&chias=$chias&chias_max=$chias_max&plots=$plots";
			for(1..$plots) {
				$data.="&chia$_=$chia_pid[$_]";
				$data.="&proz$_=$proz[$_]";
				$data.="&age$_=$age[$_]";
			}
			$data.="&cpu=$cpu";
			$data.="&totalMemory=$totalMemory";
			$data.="&freeMemory=$freeMemory";
			$data.="&freeStage=$free_stage";
			foreach $key (keys %free_farm) {
				$data.="&freeFarm$key=$free_farm{$key}";
			}
			$data.="&ppd=$ppd";
			$data.="&startNewPlot=$startNewPlot";
			$ret=get("$server_url?$data");
		}
		sleep($sleeptime-1);
		($cpu,$totalMemory,$freeMemory)=&cpu_ram();	# takes ~1s
	}
}




sub calculate_timings {
	undef @logfiles;
	undef @logfiles2;
	# check previous logs
	$ret=`dir /OD /TC /4 $logpath\\plot*.txt`;	# files only, sorted by date
	@line=split(/\n/,$ret);
	foreach(@line) {
		if($_=~/plot_q(.*?)\.txt/) {
			$filename="plot_q".$1.".txt";
			push(@logfiles,$filename);
		}
	}
	for($i=scalar(@logfiles)-1;$i>=0; $i--) {
		push(@logfiles2,$logfiles[$i]);
	}
	
	undef @phase_time;
	undef $total_time_total;
	undef $copy_time_total;
	undef @tt_total;
	
	$c=0;
	foreach $filename (@logfiles2) {
		$finished=0;
		undef $phase;
		open(LOGFILE, "<$logpath\\$filename");
		while(<LOGFILE>) {
			if($_=~/^Total time = (\d+)/) {
				$total_time=$1;
			}
			if($_=~/^Copy time = (\d+)/) {
				$copy_time=$1;
				$finished=1;
				last;
			}
			if($_=~/Time for phase (\d) = (\d+)/) {
				$phase_time[$1]+=$2;
			}
		}
		close(LOGFILE);
		next if(!$finished);
		
		$c++;
		$total_time_total+=$total_time;
		$copy_time_total+=$copy_time;
		print color "bright_white";
		print "$filename\n";
		print color "white";
		$ze=int($total_time/$plots);
		print "total: $total_time sec., 1/$plots: $ze sec., copy: $copy_time sec.\n";

		open(LOGFILE, "<$logpath\\$filename");
		while(<LOGFILE>) {
			if($_=~/Starting phase (\d)\/4:/) {
				$phase=$1;
				undef $table;
				last if($phase>1);
				undef @tt;
			}
			if($phase==1) {
				if($_=~/Computing table (\d)/) {
					$table=$1;
				}
				if($_=~/time: (\d+)/) {
					$tt[$table]=$1;
					$tt_total[$table]+=$1;
				}
			}
		}
		close(LOGFILE);
		print "P1: ";
		for(1..7) {
			print "[T$_]:$tt[$_] ";
		}
		print "\n\n";
		
		last if($c==$check_last);
	}

	$age_unix_threshold=int($total_time_total/$check_last/$plots);
	if($age_unix_threshold_override) {
		$age_unix_threshold=$age_unix_threshold_override;
		undef $age_unix_threshold_override;
	}
	$total_time=int($total_time_total/$check_last);
	$copy_time=int($copy_time_total/$check_last);
	$ppd=sprintf('%.1f',(24*3600/$total_time*$plots));	# ppd = "plots per day"
	print color "bright_magenta";
	print "AVERAGE:\n";
	for(1..4) {
		print "phase $_:".int($phase_time[$_]/$check_last)."  ";
	}
	print "\n";
	print "total: $total_time sec., 1/$plots: $age_unix_threshold sec., copy:$copy_time sec., $ppd ppd\n";
	print "P1: ";
	for(1..7) {
		$tt[$_]=int($tt_total[$_]/$check_last);
		print "[T$_]:$tt[$_] ";
	}
	print "\n\n";
	for(1..4) {
		$ptu[$_]=sprintf('%.0f',$phase_time[$_]/$check_last/$copy_time);
	}
	print color "bright_yellow";
	print "plot time units: $ptu[1] $ptu[2] $ptu[3] $ptu[4]\n";

	print color "reset";
}


sub cpu_ram {
	$ret=`wmic cpu get loadpercentage`;
	if($ret=~/(\d+)/) {
		$cpu=$1;
	}
	$ret=`wmic cpu get loadpercentage`;
	if($ret=~/(\d+)/) {
		$cpu=$1 if($1>$cpu);
	}

	$ret=`wmic ComputerSystem get TotalPhysicalMemory`;
	if($ret=~/(\d+)/) {
		$totalMemory=$1;
	}

	$ret=`wmic OS get FreePhysicalMemory`;
	if($ret=~/(\d+)/) {
		$freeMemory=$1;
	}

	$totalMemory=sprintf('%.0f',$totalMemory/1024/1024/1024);
	$freeMemory=sprintf('%.0f',$freeMemory/1024/1024);
	return ($cpu,$totalMemory,$freeMemory);
}



sub date {
	($CCtime) = @_;
	($CCsec,$CCmin,$CChour,$CCmday,$CCmon,$CCyear,$CCwday) = (localtime($CCtime))[0,1,2,3,4,5,6];
	if ($CCsec < 10) { $CCsec = "0$CCsec"; }
	if ($CCmin < 10) { $CCmin = "0$CCmin"; }
	if ($CChour < 10) { $CChour = "0$CChour"; }
	if ($CCmday < 10) { $CCmday = "0$CCmday"; }
	$CCmon++;
	if ($CCmon < 10) { $CCmon = "0$CCmon"; }
	if ($CCyear < 50) { $CCyear += 100; }
	$CCyear = $CCyear+1900;
}
