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

package Qpsmtpd::Plugin::Router::Deliver::DNS;

$Qpsmtpd::Plugin::Router::Deliver::DNS::VERSION = 0.01;

=head1 NAME

Qpsmtpd::Plugin::Router::Deliver::DNS - try to deliver a mail using smtp via DNS.

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::Deliver::DNS;
 my $agent = Qpsmtpd::Plugin::Router::Deliver::DNS->new();
 my $ok = $agent->deliver($transaction);

=head1 DESCRIPTION

Try to  deliver an email  by SMTP  via DNS. That  is, it looks  up the
detination domains MX record and tries  to deliver the message to this
mail server.  It uses the ::SMTP  agent module to actually  connect to
the server.

Doesn't do any policy switching or dns lookups, this has to be done by
the spooler (Qpsmtpd::Plugin::Router::Queue).

This  is  the  default  delivery  agent,  if  nothing  else  has  been
configured or matches.

=head1 METHODS

=cut

use Qpsmtpd::Plugin::Router::Resolver;
use Qpsmtpd::Plugin::Router::Deliver::SMTP;
use Net::SMTP;
use Qpsmtpd::Transaction;
use Try::Tiny;

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Deliver';

=head2 new()

Returns a standard DNS/MX delivery agent object.

=cut


=head2 deliver($transaction)

Try to deliver $transaction to one  of the responsible mail servers as
listed by MX.   Tries to deliver for each recipient  separately and if
successfull, remove rcpt from $transaction.

Returns arrayref containing all log messages and the possibly modified
$transaction  object or  0  if  no more  recipients  are  left in  the
transaction.

=cut

sub deliver {
  my($self, $transaction) = @_;
  my @log;

  my %list = $self->transaction2list($transaction);

  foreach my $domain (keys %list) {
    foreach my $server ($self->res->get_mx($domain)) {
      my %mx = (Host => $server, Port => 25, %{$self->defaults});
      my $qid;
      try {
        $qid = $self->deliver_msg(\%mx, $transaction, $list{$domain});
      }
      catch {
        push @log, sprintf "failed to deliver for %s via mx %s:%d: $@",
          join(',', @{$list{$domain}}), $server, 25;
        # try next mail server, don't die here!
      };

      # success
      push @log, sprintf "delivered successfully for %s via %s:%d (queued as %s)",
        join(',', @{$list{$domain}}), $server, 25, $qid;

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


1;

