#
# Copyright (c) 2016 T.v.Dein <tlinden |AT| cpan.org>.
#
# Licensed under the terms of the BSD 3-Clause License.
#
# Redistribution and use  in source and binary forms,  with or without
# modification, are  permitted provided that the  following conditions
# are met:
#
#  Redistributions  of source  code  must retain  the above  copyright
#  notice, this list of conditions and the following disclaimer.
#
#  Redistributions in  binary form must reproduce  the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation   and/or   other    materials   provided   with   the
#  distribution.
#
#  Neither  the name  of the  copyright holder  nor the  names of  its
#  contributors may  be used  to endorse  or promote  products derived
#  from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY  THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS"  AND ANY EXPRESS  OR IMPLIED WARRANTIES, INCLUDING,  BUT NOT
# LIMITED TO,  THE IMPLIED  WARRANTIES OF MERCHANTABILITY  AND FITNESS
# FOR  A PARTICULAR  PURPOSE ARE  DISCLAIMED.  IN NO  EVENT SHALL  THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT  LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS  OR SERVICES;
# LOSS OF  USE, DATA,  OR PROFITS;  OR BUSINESS  INTERRUPTION) HOWEVER
# CAUSED AND ON  ANY THEORY OF LIABILITY, WHETHER  IN CONTRACT, STRICT
# LIABILITY, OR  TORT (INCLUDING  NEGLIGENCE OR OTHERWISE)  ARISING IN
# ANY WAY  OUT OF  THE USE OF  THIS SOFTWARE, EVEN  IF ADVISED  OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# Part of Qpsmtpd::Plugin::Router:
# https://github.com/TLINDEN/Qpsmtpd-Plugin-Router

package Qpsmtpd::Plugin::Router::Policy;

$Qpsmtpd::Plugin::Router::Policy::VERSION = 0.01;





=head1 NAME

Qpsmtpd::Plugin::Router::Policy - parse policy and config.

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::Policy;
 my $policy = Qpsmtpd::Plugin::Router::Policy->new(..);
 print $policy->spool_directory;

=head1 DESCRIPTION

Parse transports policy and qpsmtpd plugin config and store everything
in a policy object for easy access.

=head1 METHODS

=cut

use Qpsmtpd::Plugin::Router::Deliver::SMTP;
use Qpsmtpd::Plugin::Router::Deliver::MDA;
use Qpsmtpd::Plugin::Router::Deliver::ToPlugin;
use Qpsmtpd::Plugin::Router::Deliver::DNS;


use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Role';

=head2 new(policy => $file, [defs => $file])

Return parsed policy as hash-ref. Policy parameter is mandatory.

=cut

has policyfile => (
               is       => 'rw',
               required => 1,
               isa      => sub {
                 if (defined $_[0]) {
                   if (! -r $_[0]) {
                     die "Policy file $_[0] does not exist or is not readable!";
                   }
                 }
                 else {
                   die "Please provide a policy file name!";
                 }
               },
              );

has defsfile => ( # optional
             is  => 'rw',
             isa => sub {
               if (defined $_[0]) {
                 if (! -r $_[0]) {
                   die "Policy DEF file $_[0] does not exist or is not readable!";
                 }
               }
               else {
                 die "Please provide a policy DEF file name!";
               }
             },
            );

has vars => (  # hash ref containing vars
             is     => 'rw',
             traits => ['Hash']
            );

has policy => (  # array ref containing rules
               is     => 'rw',
               traits => ['Array']
              );


sub BUILD {
  my ($self, $args) = @_;

  if ($self->defsfile) {
    $self->_parse_defs();
  }

  if ($self->policyfile) {
    $self->_parse_policy();
  }
  else {
    $self->policy([ $self->rule_default ]);
  }
}

=head2 route($transport)

Try to route $transport according to $self->policy.

Returns (modified) $transaction or 0 if no rule has matched.

Called from daemonized Router per queue.

=cut

sub route {
  my ($self, $transport) = @_;

  foreach my $rule (@{$self->policy}) {
    if ($transaction->{m_domain} =~ /$rule->{regex}/) {
      return $rule->{agent}->deliver($transaction);
    }
  }

  return 0; # no rule matched, reject message
}




#
# internal: variable file parser, sets $self->vars hash ref
sub _parse_defs {
  my ($self) = @_;
  my %vars;
  if (open D, "<" . $self->defsfile) {
    while (<D>) {
      chomp;
      next if(/^\s*$/ || /^\s*#/);
      my ($var, $val) = split /\s\s*/, $_, 2;
      $vars{$var} = $val;
    }
    close D;
    $self->vars(\%vars);
  }
  else {
    die "Could not read " . $self->defsfile . ": $!\n";
  }
}

#
# internal: policy file parser, sets $self->policy array ref
# which consists of: { regex => $regex, agent => $deliverobj }, where agent is an
# instance of ::Deliver::*.
sub _parse_policy {
  my ($self) = @_;
  my @policy;

  if (open D, "<" . $self->policyfile) {
    while (<D>) {
      chomp;
      next if(/^\s*$/ || /^\s*#/);
      my($if, $then) =  split /\s\s*/, $_, 2;
      push @policy, {regex => $self->_rule_p($if),
                     agent => $self->_deliver_p($then)};
    }
    close D;
    push @policy, $self->_rule_default();
    $self->policy(\@policy);
  }
  else {
    die "Could not read " . $self->policyfile . ": $!\n";
  }
}

#
# internal: parse rule entry and convert to compiled regex
sub _rule_p {
  my ($self, $if) = @_;

  if ($if =~ /^\/(.*)\//) {
    # regular regex, keep as is
    return qr/$1/io;
  }
  elsif ($if =~ /\*/) {
    # glob, always matches the whole thing
    $if =~ s/\*/\.\*/g;
    return qr/^${if}$/io;
  }
  else {
    # domain, only matches against the end-of-string
    return qr/$if$/io;
  }
}

#
# internal: action (then) parser, instantiates an apropriate Deliver
# instance, if one matches, croaks otherwise
sub _deliver_p {
  my ($self, $then) = @_;

  # try to interpolate
  if ($self->vars) {
    $then =~ s/\$([a-zA-Z0-9\-_]+)/
      my $n = $1;
      if (exists $self->vars->{$n}) {
        $self->vars->{$n};
      }
      else {
        "";
      }
    /gex;
  }

  # check action type
  if ($then =~ /^\|(.*)/ || $then =~ /^(\\.*)/) {
    my $exec = $1;
    if (-e $exec) {
      return Qpsmtpd::Plugin::Router::Deliver::MDA->new(exec => $exec);
    }
    else {
      die "Failed to locate executable $exec: not executable, readable or non-existent";
    }
  }
  elsif ($then =~ /^queue\/.*/) {
    return Qpsmtpd::Plugin::Router::Deliver::ToPlugin->new(plugin => $then);
  }
  else {
    # threat everything else as mailserver
    return Qpsmtpd::Plugin::Router::Deliver::SMTP->new(server => $then);
  }
}

#
# will be added as last entry to policy (if there's one)
sub _rule_default {
  my ($self) = @_;
  return { regex => qr/.*/,
           agent => Qpsmtpd::Plugin::Router::Deliver::DNS->new() };
}

1;
