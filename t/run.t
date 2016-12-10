# -*-perl-*-

use utf8;
use Data::Dumper;
use Test::More qw(no_plan);

require_ok ('Qpsmtpd::Plugin::Router');

my $pwd = `pwd`;
chomp $pwd;

# FS tests
{
  require_ok ('Qpsmtpd::Plugin::Router::FS');

  # create
  unlink "t/testfile";

  my $fs = Qpsmtpd::Plugin::Router::FS->new(spooldir => "$pwd/t");
  ok($fs, "::FS obj");

  # create
  ok($fs->put("testfile", "helloworld"), "::FS->put()");

  # do not overwrite
  eval { $fs->put("testfile", "helloworld"); };
  ok($@, "::FS->put() shall fail with existing file");

  # fetch
  ok($fs->get("testfile") eq "helloworld", "::FS->get() shall return file content");
}


# Resolver tests
{
  require_ok ('Qpsmtpd::Plugin::Router::Resolver');

  my $dns = Qpsmtpd::Plugin::Router::Resolver->new();
  ok($dns, "::Resolver obj");

  # ips
  my @ips = $dns->get_ip("google.com");
  #diag(Dumper(\@ips));
  ok(@ips, "Resolve google.com");

  # mx's
  my @mx = $dns->get_mx("google.com");
  #diag(Dumper(\@mx));
  ok(@mx, "Get google.com MX records");

  # !
  eval { $dns->get_ip("blah.comcomcom"); };
  ok($@, "Die with NXDOMAIN on error");
}


# Policy tests
{
  require_ok ('Qpsmtpd::Plugin::Router::Policy');

  my $p = Qpsmtpd::Plugin::Router::Policy->new(defsfile => "t/defsfile", policyfile => "t/policyfile");
  ok($p, "::Policy obj");
}


# Serializer
{
  require_ok ('Qpsmtpd::Plugin::Router::Serialize');

  my $S = Qpsmtpd::Plugin::Router::Serialize->new();
  ok($S, "::Serializer obj");

  # obj to dump
  my $t = Qpsmtpd::Plugin::Router::Resolver->new();
  ok($S->conserve($t, "$pwd/t/testqfile"), "Freeze object to disk");
}

# Aliases parser
{
  require_ok ('Qpsmtpd::Plugin::Router::Aliases');

  my $A = Qpsmtpd::Plugin::Router::Aliases->new(aliases => ['t/aliasfile']);
  ok($A, "::ALias obj");

  ok($A->mail2user('prinfo@bar.com') eq 'foo', "Resolve mail address to user");
}

done_testing();
