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


package Qpsmtpd::Plugin::Router;

$Qpsmtpd::Plugin::Router::VERSION = 0.01;

=head1 NAME

Qpsmtpd::Plugin::Router - router base class

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router;
 my $router = Qpsmtpd::Plugin::Router->new(..);

 # fork  spool  daemon, if  required  after  forking initialize  queue
 # managers (incoming, deferred) from Queue.pm
 $router->daemonize();

 # spool incoming mail  into incoming sub queue, called  by plugin for
 # every transaction, applies rewriting and virtualusers
 $router->incoming($transaction);

 exit;

=head1 DESCRIPTION

Primary interface for router. Does initialization, starts the spooling
daemon, etc.

=head1 METHODS

=cut

use File::Spec::Functions qw(splitpath file_name_is_absolute catfile);

use Qpsmtpd::Plugin::Router::FS;
use Qpsmtpd::Plugin::Router::Serialize;
use Qpsmtpd::Plugin::Router::Policy;
use Qpsmtpd::Plugin::Router::Rewrite;
use Qpsmtpd::Plugin::Router::Aliases;

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Role';

=head2 new(polcy => [], aliases => [], pidfile => $file)

Return new router object. Does not do anything otherwise.

=cut

# inline helper objects
has policy  => (is => 'rw');
has aliases => (is => 'rw');
has rewrite => (is => 'rw');
has fs      => (is => 'rw');
has ser     => (is => 'rw');


sub BUILD {
  my($self, $args) = @_;

  my $spool = catfile($self->config->spooldir, 'incoming');

  my $fs  = Qpsmtpd::Plugin::Router::FS->new(spooldir => $spool);
  my $ser = Qpsmtpd::Plugin::Router::Serialize->new(fs => $fs);
  my $pol = Qpsmtpd::Plugin::Router::Policy->new(policyfile => $self->config->transports,
                                                 defsfile   => $self->config->transportdefs);
  my $rew = Qpsmtpd::Plugin::Router::Rewrite->new(rewritingfile => $self->config->rewriting);
  my $al  = Qpsmtpd::Plugin::Router::Aliases->new(aliasfile => $self->config->aliases);

  $self->fs($fs);
  $self->serializer($ser);
  $self->policy($pol); # FIXME: only needed for daemon, instanciate later?
                       # add aliases obj for MDA agent
  $self->rewrite($rew);
  $self->alliases($al);
}

=head2 spooler()

Fork and spool.

1 fork
2 one queue manager per spooldir (incoming, deferred)
3 loop endless

inside 3):
foreach @queueobj
  $queue->checkspool
    foreach queuefile
      mv active queue
      transaction = thaw()
      policy->route(transaction)
      remove || mv => deferred

=cut

sub spooler {

}


=head2 incoming($transaction)

Apply   rewriting  and   virtual-domain,  then   dissect  $transaction
domain-wise, give queue-ids, put into incoming queue.

Called from queue/router plugin on hook_queue.

=cut

sub incoming {
  my($self, $transaction) = @_;

  # first step, check rewriting
  # FIXME: move to Rewrite module
  if ($self->rewrite) {
    # rewrite envelope recipient(s)
    my $rcpts = $transaction->recipients;
    my @newrcpts;
    foreach my $rcpt (@{$rcpts}) {
      my $address = $rcpt->address;
      foreach my $rule (@{$self->rewrite}) {
        $address =~ s/$rule->{search}/$rule->{replace}/i;
      }
      if ($address ne $rcpt->address) {
        $rcpt->address($address);
      }
      push @newrcpts, $rcpt;
    }
    $transaction->recipients(\@newrcpts);

    # rewrite envelope sender
    my $sender = $transaction->sender;
    my $address = $sender->address;
    foreach my $rule (@{$self->rewrite}) {
      $address =~ s/$rule->{search}/$rule->{replace}/i;
    }
    if ($address ne $sender->address) {
      $sender->address($address);
      $transaction->sender($sender);
    }

    if ($self->both) {
      # rewrite mail headers as well
      my $header = $transaction->header->dup;
      foreach my $TAG (qw(From To CC BCC)) {
        if (grep {$TAG eq $_} $header->tags) {
          my $val = $header->get($TAG);
          foreach my $rule (@{$self->rewrite}) {
            $val =~ s/$rule->{search}/$rule->{replace}/i;
          }
          if ($val ne $header->get($TAG)) {
            $header->replace($TAG, $val);
          }
        }
      }
      $transaction->header($header);
    }
  }

  # finally, dissect, if neccessary
  my %domains = $self->transaction2list($transaction);

  if (scalar keys %domains == 1) {
    # only one, do NOT dissect
    $self->incomingtransaction($transaction, (keys %domains)[0]);
  }
  else {
    # multiple domains, DO dissect
    foreach my $domain (keys %domains) {
      my $clone = $self->clonetransaction($transaction);
      $clone->recipients = $domains{$domain}; # now only contains rcpts of this domain
      $self->incomingtransaction($clone, $domain);
    }
  }
}


=head2 incomingtransaction($transaction, $domain)

Actually  put the  transaction  into the  incoming queue.  Initializes
$transaction META flags (starting with m_).

=cut

sub incomingtransaction {
  my($self, $transaction, $domain) = @_;

  $transaction->{m_queueid} = $self->queueid; # required by FS and logging
  $transaction->{m_domain}  = $domain;        # required by policy

  $self->ser->conserve($transaction, $transaction->{m_queueid});

  return $transaction->{m_queueid};
}




=head2 queueid()

Return a new queueid.

=cut

sub queueid {
  die "FIXME";
}


1;

