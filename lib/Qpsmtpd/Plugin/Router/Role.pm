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


package Qpsmtpd::Plugin::Router::Role;

$Qpsmtpd::Plugin::Router::Role::VERSION = 0.01;

=head1 NAME

Qpsmtpd::Plugin::Router::Role - globals

=head1 SYNOPSIS

 with 'Qpsmtpd::Plugin::Router::Role';

=head1 DESCRIPTION

Router roles.

=cut

use Try::Tiny;

use Moo::Role;
use strictures 2;
use namespace::clean;

has log => ( is => 'rw' ); # supply with new() like new(log => sub { return $qp->log(@_); }

has config => (is => 'rw'); # shall contain the plugin config has hash ref

has qp => (is => 'rw'); # shall contain the qp object ref

=head2 clone-transaction($transaction)

Return a cloned copy of $transaction object.

=cut

sub clone-transaction {
  my ($self, $transaction) = @_;

  my $hash;

  foreach my $attr (keys %{$transaction}) {
    $hash->{$attr} = $transaction->{$attr};
  }

  my $copy = bless $hash, ref $transaction;

  return $copy;
}


=head2 transaction2list($transaction)

Returns a hash of { $domain => [$rcpt,...] }.

=cut

sub transaction2list {
  my($self, $transaction) = @_;

  my %list;
  foreach my $rcpt ($transaction->recipients) {
    push @{$list{$rcpt->host}}, $rcpt;
  }

  return %list;
}


=head2 transaction2addrlist($transaction)

Return array of recipient adresses.

=cut

sub transaction2addrlist {
  my($self, $transaction) = @_;
  my @list = map { $_->address } $transaction->recipients;
  return @list;
}


=head2 rcpt2user($rcpt)

Returns user part of email address (the stuff before @).

=cut

sub rcpt2user {
  my($self, $rcpt) = @_;
  my($user, $domain) = $rcpt->canonify($rcpt->address);
  return $user;
}

=head2 transaction2message($transaction)

Returns ASCII representation of $transaction.

=cut

sub transaction2message {
  my($self, $transaction) = @_;

  my $mail = $transaction->header->as_string . "\n";
  $transaction->body_resetpos;
  while (my $line = $transaction->body_getline) {
    $mail .= $line;
  }

  return $mail;
}


1;

