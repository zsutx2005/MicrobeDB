#!/usr/bin/perl
#Unpacks (tar/gzip) genome files from ftp download
#This is usually run after download_version.pl (by the download_load_and_delete_old_version.pl)

use strict;
use warnings;
use Parallel::ForkManager;
use Getopt::Long;
use Log::Log4perl;
use Sys::CPU;
  
my ($download_dir,$logger_cfg,$help,$parallel);
my $res = GetOptions("directory=s" => \$download_dir,
		     "parallel:i"=>\$parallel,
		     "logger=s" => \$logger_cfg,
		     "help"=>\$help,
    );

my $usage = "Usage: $0 [-p <num_cpu>][-l <logger.conf>] [-h] -d directory \n";
my $long_usage = $usage.
    "Options:
-d or --directory <directory> : Mandatory. A directory containing directories of genomes to be loaded into MicrobeDB. 
-p or --parallel: Using this option without a value will use all cpus, while giving it a value will limit to that many cpus. Without option only one cpu is used. 
-l or --logger <logger config file>: alternative logger.conf file
-h or --help : Show more information for usage.
";
die $long_usage if $help;

die $usage unless $download_dir;


# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

# Clean up the download path
$download_dir .= '/' unless $download_dir =~ /\/$/;


my $cpu_count=1;

#if the option is set
if(defined($parallel)){
    #option is set but with no value then use the max number of proccessors
    if($parallel ==0){
	$cpu_count= Sys::CPU::cpu_count();
    }else{
	$cpu_count=$parallel;
    }
}

$logger->info("Parallel proccessing the unpacking step with $cpu_count proccesses.") if defined($parallel);
my $pm = new Parallel::ForkManager($cpu_count);


chdir($download_dir);
my @compressed_files = glob($download_dir .'all.*.tar.gz');
for my $tarball (@compressed_files){
    my $pid = $pm->start and next; 
    $logger->info("Unpacking $tarball");
    my $status= system("tar xzf $tarball");
    if($status){
	$logger->fatal("Unpacking of $tarball failed!");
	die;
    }else{
	$logger->info("Done unpacking and now deleting $tarball");
	unlink($tarball);
    }
     $pm->finish;
}
$pm->wait_all_children;
$logger->info("All done unpacking.");
