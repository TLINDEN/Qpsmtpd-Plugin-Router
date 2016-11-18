#/usr/bin/perl
use lib qw(lib);
use Carp;
use Net::SMTP;
use Data::Dumper;

$SIG{__DIE__} = \&Carp::confess;


my $s = Net::SMTP->new("mx.daemon.de", Port => 25) or die $!;
print "SSL\n" if($s->message =~ /STARTTLS/);

use Net::SMTP;



exit;
# use Qpsmtpd::Plugin::Router::FS;
# my $fs = Qpsmtpd::Plugin::Router::FS->new(spooldir => "/tmp");

# print $fs->put("test", "hahaha");
# print "\n";

# print $fs->err;

