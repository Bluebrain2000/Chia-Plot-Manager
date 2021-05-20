# Chia-Plot-Manager
Chia Plot Manager for Windows, written in Perl

The Chia Plot Manager analyses the previous logfiles to calculate optimum timings for staggering and parallel plotting and also displaying the progress.
It allows to fully automate your plotting machine for unattended, parallel plotting with maximum efficiency.

Originally, this tool was not intended to be published.
But as I was asked for it, I'll provide it "as is".

If you find it useful, you are welcome to tip me a beer in Chia:
xch1vjlvu8v8gjt0pl0usv028nx7yqhac3d0nneq7y5n7vyg5hkhvans7fvp8r

You'll need a Perl enviroment under Windows.
https://strawberryperl.com/
install the needed modules via command line with:
cpan -i Date::Calc
cpan -i Term::ANSIColor
cpan -i LWP::Simple
cpan -i Win32::DriveInfo

You'all also need the pslist.exe from Microsoft's free PsTools
https://docs.microsoft.com/en-us/sysinternals/downloads/pstools
Just copy the pslist.exe in the same directory as plotman.pl

Edit plotman.conf.pl to your needs.

start the Plot Manager with:
perl plotman.pl
