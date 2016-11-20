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

package Qpsmtpd::Plugin::Router::Deliver::MDA;

$Qpsmtpd::Plugin::Router::Deliver::MDA::VERSION = 0.01;

=head1 NAME

Qpsmtpd::Plugin::Router::Deliver::MDA - try to deliver a mail to an MDA.

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::Deliver::MDA;
 my $mda = Qpsmtpd::Plugin::Router::Deliver::MDA->new(..);
 my $ok = $mda->deliver($transaction, $program);

=head1 DESCRIPTION

Try to  deliver an email  by piping it to  the stdin of  the specified
program, doesn't do  any policy switching, this has to  be done by the
spooler (Qpsmtpd::Plugin::Router::Queue).

Must be used for all pipe related delivery methods (MDA, Mailrobot etc).

=head2 METHODS

=cut

use Qpsmtpd::Transaction;
use Try::Tiny;
use FileHandle;
use IPC::Run3;

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Deliver';

=head2 new(program => $program)

Return new delivery agent object for local delivery to $program.

=cut

has program => (
                is => 'rw',
                builder => sub {
                  if (! -x $_[0]) {
                    die "$_[0] is not executable or does not exist";
                  }
                }
               );


=head2 deliver($transaction)

Try to deliver $transaction to $self->program via STDIN.

=cut

sub deliver {
  my($self, $transaction) = @_;
  my @log;

  foreach my $rcpt ($transaction->recipients) {
    my $mail = $transaction->header->as_string . "\n";
    $transaction->body_resetpos;
    while (my $line = $transaction->body_getline) {
      print $pipe $line;
    }

    my($output);

    eval {
      local $SIG{ALRM} = sub { die "alarm\n" };
      alarm 10;
      run3($self->program, $mail, \$output, \$output);
      alarm 0;
    };

    if ($@) {
      die $self->program . " timed out";
    }

    if ($? != 0) {
      die $self->program . " failed with $?: $output";
    }

    # success
    push @log, sprintf "delivered successfully for %s via %s (which said: %s)",
      $rcpt->address, $self->program, $output;
  }
}


1;

