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

package Qpsmtpd::Plugin::Router::Deliver;

$Qpsmtpd::Plugin::Router::Deliver::VERSION = 0.01;

=head1 NAME

Qpsmtpd::Plugin::Router::Deliver - delivery base class.

=head1 SYNOPSIS

 with Qpsmtpd::Plugin::Router::Deliver;

=head1 DESCRIPTION

=head1 METHODS

=cut

use Qpsmtpd::Plugin::Router::Resolver;
use Net::SMTP;
use Qpsmtpd::Transaction;
use Try::Tiny;

use Moo::Role;
use strictures 2;
use namespace::clean;

=head2 new()

Returns a standard DNS/MX delivery agent object.

=cut

has res => (
            is => 'rw',
            builder => sub {
              return Qpsmtpd::Plugin::Router::Resolver->new();
            }
           );

has Timeout => (
                is => 'rw',
                default => 10
               );

has Hello => (
              is => 'rw',
              default => 'localhost'
             );

has LocalAddr => (
                  is => 'rw',
                 );

has defaults => (
                 is => 'rw',
                );

sub BUILD {
  my($self, $args) = @_;

  my $defaults = {Timeout => $self->Timeout,
                  Hello   => $self->Hello    };
  if ($self->LocalAddr) {
    $defaults->{LocalAddr} = $self->LocalAddr;
  }

  $self->defaults($defaults);
}



1;

