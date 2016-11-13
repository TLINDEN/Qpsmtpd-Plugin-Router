# -*-perl-*-

use utf8;
use Test::More qw(no_plan);

require_ok ('Qpsmtpd::Plugin::Router');
require_ok ('Qpsmtpd::Plugin::Router::FS');

# FS tests
{
  # create
  unlink "t/testfile";
  my $pwd = `pwd`;
  chomp $pwd;
  my $fs = Qpsmtpd::Plugin::Router::FS->new(spooldir => "$pwd/t");
  ok($fs, "::FS obj");
  ok($fs->put("testfile", "helloworld"), "::FS->put()");
  diag($fs->err);

  # do not overwrite
  ok(1 != $fs->put("testfile", "helloworld"), "::FS->put() shall fail with existing file");
  diag($fs->err);

  # fetch
  ok($fs->get("testfile") eq "helloworld", "::FS->get() shall return file content");
  diag($fs->err);
}

done_testing();
