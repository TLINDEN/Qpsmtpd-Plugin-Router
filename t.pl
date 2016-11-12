#/usr/bin/perl
use lib qw(lib);

use Qpsmtpd::Plugin::Router::FS;
my $fs = Qpsmtpd::Plugin::Router::FS->new(spooldir => "/tmp");

print $fs->put("test", "hahaha");
print "\n";

print $fs->err;

