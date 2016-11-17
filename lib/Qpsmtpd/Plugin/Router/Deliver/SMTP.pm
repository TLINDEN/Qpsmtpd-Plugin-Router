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
#use Qpsmtpd::Transaction;

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Role';


=head2 new(server => "host[:port][,...]")

Return new ::SMTP delivery agent object,  which can be used to deliver
mails using SMTP to the specified servers.

=cut

has server => (
               is => 'rw',
               );

has servers => (
                is     => 'rw',
                traits => ['Array']
                );


sub BUILD {
  my($self, $args) = @_;

  my $res = Qpsmtpd::Plugin::Router::Resolver->new();

  my @servers = $res->parse($self->server);
  if (!@servers) {
    die $res->err;
  }
  else {
    my @smtp;
    foreach my $S (@servers) {
      push @smtp, Net::SMTP->new(Host    => $S->host,
                                 Port    => $S->Port,
                                 Timeout => 10,       # FIXME: make configurable
                                 Hello   => 'FIXME'   # dito.
                                 #LocalAddr => ? # check if we have to use a bind ip
                                ) or die $!;
    }
    $self->servers(\@smtp);
  }
}


=head2 deliver($transaction)

Try  to  deliver $transaction  to  one  of $self->servers.   Tries  to
deliver for each recipient separately  and if successfull, remove rcpt
from $transaction;

Returns arrayref containing all log messages and the possibly modified
$transaction  object or  0  if  no more  recipients  are  left in  the
transaction.

=cut

sub deliver {
  my($self, $transaction) = @_;
  my @log;

  foreach my $rcpt ($transaction->recipients) {
    foreach my $smtp (@{$self->servers}) { # FIXME: add some kind of loadbalancing function to select server
      eval {
        $smtp->mail($transaction->sender->address || "") or die $!;
        $smtp->to($rcpt->address) or die $!;
        $smtp->data() or die $!;
        $smtp->datasend($transaction->header->as_string) or die $!;
        $transaction->body_resetpos;
        while (my $line = $transaction->body_getline) {
          $smtp->datasend($line) or die $!;
        }
        $smtp->dataend() or die $!;
      };

      if ($@) {
        push @log, sprintf "failed to deliver for %s via %s:%d: $@",
          $rcpt->address, $smtp->host, $smtp->port;
        # next mail server
      }
      else {
        my $qid = $smtp->message();
        my @list = split(' ', $qid);
        $qid = pop(@list);

        push @log, sprintf "delivered successfully for %s via %s:%d (queued as %s)",
          $rcpt->address, $smtp->host, $smtp->port, $qid;

        $transaction->remove_recipient($rcpt);
        last; # next rcpt
      }
    }
  }

  if ($transaction->recipients) {
    return (\@log, $transaction);
  }
  else {
    return (\@log, 0);
  }
}




1;
