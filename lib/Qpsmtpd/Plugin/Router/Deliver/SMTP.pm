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

package Qpsmtpd::Plugin::Router::Deliver::SMTP;

$Qpsmtpd::Plugin::Router::Deliver::SMTP::VERSION = 0.01;


=head1 NAME

Qpsmtpd::Plugin::Router::Deliver::SMTP - try to deliver a mail using smtp.

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::Deliver::SMTP;
 my $smtp = Qpsmtpd::Plugin::Router::Deliver::SMTP->new(..);
 my $ok = $smtp->deliver($transaction, $server, $port);

=head1 DESCRIPTION

Try to  deliver an email by  SMTP, doesn't do any  policy switching or
dns lookups, this has to be done by the spooler (Qpsmtpd::Plugin::Router::Queue).

=head1 METHODS

=cut

use Qpsmtpd::Plugin::Router::Resolver;
use Net::SMTP;
use Qpsmtpd::Transaction;

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Role';
with 'Qpsmtpd::Plugin::Router::Deliver';


=head2 new(server => "host[:port][,...]", Timeout => 10, Hello => 'mailgwfoo.bar', LocalAddr => undef)

Return new ::SMTP delivery agent object,  which can be used to deliver
mails using SMTP to the specified server[s].

All  L<Net::SMTP> parameters  can be  supplied which  will be  used as
defaults for all mailservers.

=cut

has servers => (
                is     => 'rw',
                traits => ['Array']
               );

has server => (
               is => 'rw',
               );

sub BUILD {
  my($self, $args) = @_;

  my @servers = $self->res->parse($self->server, $self->defaults); # defaults from base class

  $self->servers(\@servers);
}


=head2 deliver($transaction)

Try  to  deliver $transaction  to  one  of $self->servers.   Tries  to
deliver for each recipient separately  and if successfull, remove rcpt
from $transaction.

Returns arrayref containing all log messages and the possibly modified
$transaction  object or  0  if  no more  recipients  are  left in  the
transaction.

=cut

sub deliver {
  my($self, $transaction) = @_;
  my @log;

  my %list = $self->transaction2list($transaction);

  foreach my $domain (keys %list) {
    foreach my $server (@{$self->servers}) {
      my $qid;
      try {
        $qid = $self->deliver_msg($server, $transaction, $list{$domain});
      }
      catch {
        push @log, sprintf "failed to deliver for %s via transport %s:%d: $@",
          join(',', @{$list{$domain}}), $server->Host, $server->Port;
        # try next mail server, don't die here!
      };

      # success
      push @log, sprintf "delivered successfully for %s via %s:%d (queued as %s)",
        join(',', @{$list{$domain}}), $server->Host, $server->Port, $qid;

      foreach my $rcpt (@{$list{$domain}}) {
        $transaction->remove_recipient($rcpt);
      }
      last; # next rcpt
    }
  }

  if ($transaction->recipients) {
    return (\@log, $transaction);
  }
  else {
    return (\@log, 0);
  }
}


=head2 deliver_msg($serverobj, $transaction, $recipients)

Try to deliver $transaction for  @$recipients to $serverobj (a Net::SMTP
object). Returns the queueid of remote.

=cut

sub deliver_msg {
  my($self, $server, $transaction, $recipients) = @_;

  my $smtp = Net::SMTP->new(%{$server}) or die "Could not connect to $server->{Host}: $!";

  if ($smtp->message =~ /starttls/i) {
    $smtp->starttls() or die "Could not establish TLS session to $server->{Host}: $!";
  }

  $smtp->mail($transaction->sender->address || "")
    or die "Could not set sender to " . $transaction->sender->address . "on $server->{Host}: $!";

  foreach my $rcpt (@{$recipients}) {
    $smtp->to($rcpt->address)
      or die "Could not set recipient to " . $rcpt->address . "on $server->{Host}: $!";
  }

  $smtp->data()
    or die "Could not start DATA on $server->{Host}: $!";

  $smtp->datasend($transaction->header->as_string)
    or die "Could not send DATA on $server->{Host}: $!";

  $transaction->body_resetpos;
  while (my $line = $transaction->body_getline) {
    $smtp->datasend($line)
      or die "Could not send body LINE on $server->{Host}: $!";
  }

  $smtp->dataend()
    or die "Could not finish DATA on $server->{Host}: $!";

  my $qid = $smtp->message();
  $smtp->quit();
  my @list = split(' ', $qid);
  $qid = pop(@list);

  return $qid;
}



=head2 _select_server()

FIXME:

Return next server based on some algorithm, if any.

Work as a sort() routine, possible sort methods:

- by appearance
- by response time
- by load
- random
- somehow user specified


=cut



1;
