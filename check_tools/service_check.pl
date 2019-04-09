#!/usr/bin/env perl
=head1 NAME

service_check.pl - get the host and service list from influxdb's 
"db"."autogen"."{system, memcached, mysql, redis}", filter the 
expired lastest items and insert it back to "db"."autogen"."service_check".

note: the `service_check.pl` can be used with `service_check.tick`
to get the alert message when host is dead or missing the
lastest data.

=head1 SYNOPSIS

    use service_check.pl --help for more info.

    options:
       server|s:  influxdb host address, default is localhost:8086.
       db|d:      influxdb's database which holds the series data.
       user|u:    influxdb's username.
       password|p influxdb's user password.
       delay|t:   delay seconds ago will be consider as expire time, 
                  default is 60, delay time should greater than telegraf's
                  `interval + jitter + flush_interval + flush_jitter`
       verbose|v: print verbose message.

=cut

use strict;
use Getopt::Long;
use Data::Dumper;
use POSIX qw(strftime);
use LWP::UserAgent;
use URI::Encode qw(uri_encode);
use HTTP::Request::Common;
use JSON qw(from_json to_json);
use DateTime;
use POSIX qw(strftime);

my $server = 'localhost:8086';
my $verbose = 0;
my $db = 'hostmonitor';
my $user = undef;
my $password = undef;
my $help = 0;
my $delay = 65;

GetOptions(
   "server|s=s"   => \$server,
   "db|d=s"       => \$db,
   "user|u=s"     => \$user,
   "password|p=s" => \$password,
   "verbose|v!"   => \$verbose,
   "help|h!"      => \$help,
);

sub get_time {
    return strftime("%Y-%m-%dT%H:%M:%S", localtime(time));
}

sub echo_msg {
    my $str = shift;
    my $now = get_time();
    print "[$now] $str\n";
}

if ($help) {
    usage($0);
}

sub usage {
    my $name = shift;
    system("perldoc -T $name");
    exit 0;
}

sub set_data {
    my ($ua, $data) = @_;
    my $keyurl = "http://$server/write?db=$db";
    if(defined($user) && defined($password)) {
       $keyurl .= "&u=$user&p=$password";
    }

    my $status = 1; # default is success
    foreach my $k (@$data) {
      echo_msg("[verbose] service_check,$k") if $verbose;
      my $request =
         HTTP::Request::Common::POST(
           $keyurl,
           'User-Agent' => 'influx_curl0.1',
           'Content' => "service_check,$k",
         );
       my $res = $ua->request($request);
       unless ($res->is_success) {
         $status = 0;
       }
    }

    return $status;
}

sub get_data {
    my ($ua, $sql) = @_;
    my $keyurl = "http://$server/query?db=$db";
    if(defined($user) && defined($password)) {
      $keyurl .= "&u=$user&p=$password";
    }

    my $request  =   
        HTTP::Request::Common::POST(
                   $keyurl,
                   'User-Agent' => 'influx_curl0.1',
                   'Content' => "q=$sql"
                 );  
    my $res = $ua->request($request);
    unless ($res->is_success) {
        return undef;
    }   
    return $res->{'_content'};
}

# convert UTC time to epoch second
sub get_epoch {
    my $time = shift;
    $time =~ s/\.\d+Z$//g;
    my($year, $mon, $day, $hour, $min, $sec) 
        = split(/(?:-|T|:|Z)/i, $time);

    my $dt = DateTime->new(
       year   => $year,
       month  => $mon,
       day    => $day,
       hour   => $hour,
       minute => $min,
       second => $sec,
       time_zone => 'UTC',
    );

    return $dt->epoch;
}

sub item_filter {
    my $k     = shift;
    my $metric= shift;
    my $now   = shift;
    my $delay = shift;
    my $dc    = $k->{'tags'}->{'dc'};
    my $host  = $k->{'tags'}->{'host'};
    my $server= $k->{'tags'}->{'server'} || 'host';
    my $port  = $k->{'tags'}->{'port'};
    if (defined($port)) {
      $server .= ":$port";
    }

    my $time  = $k->{'values'}->[0][0];

    my $res = undef;
    my $time_epoch   = get_epoch($time);
    my $isTimeExpire = 0;
    my $time_diff    = $now - $time_epoch;
    if ($time_diff > $delay) {
      if ($time_diff > 86400) {
        $isTimeExpire = 3; # this host maybe already removed!
      }
      elsif ($time_diff > 3600) {
        $isTimeExpire = 2; # too long time, should be critical level
      }
      else {
        $isTimeExpire = 1; # warning level.
      }
    }
    $res = "dc=$dc,host=$host,server=$server,service=$metric "
         . "isTimeExpire=$isTimeExpire";
    echo_msg("last_time: $time, res: $res") if $verbose;
    return $res;
}

my $now = time;
my %sql_query = (
  'system' => <<"SQL_END",
select last("uptime") as lu from system  group by dc, host
SQL_END

  'mysql'  => <<"SQL_END",
select last("uptime") as lu from mysql  group by dc, host, server
SQL_END

  'redis'  => <<"SQL_END",
select last("uptime") as lu from redis group by dc, host, server, port
SQL_END
 
  'memcached' => <<"SQL_END",
select last("uptime") as lu from memcached group by dc, host, server
SQL_END
);

my %delay_ref = (
  system => $delay,
  mysql  => 185,
  redis  => $delay,
  memcached => $delay,
);

# http client
my $ua = LWP::UserAgent->new;
$ua->timeout(5);

foreach my $metric (qw(system mysql redis memcached)) {
  my $query = get_data($ua, $sql_query{$metric});
  my $json = from_json($query);

  my @items;
  foreach my $k (@{$json->{'results'}}) {
    foreach my $v (@{$k->{'series'}}) {
      my $key = item_filter($v, $metric, $now, $delay_ref{$metric});
      push @items, $key if defined $key;
    }
  }

  if (set_data($ua, \@items)) {
    echo_msg("insert [$metric] data ok!");
  }
}

=head1 AUTHOR

zhe.chen <chenzhe07@gmail.com>

=head1 CHANGELOG

v0.1.0 version

=cut
