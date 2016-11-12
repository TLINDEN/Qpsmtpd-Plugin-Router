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

package Qpsmtpd::Plugin::Router::Resolver;

$Qpsmtpd::Plugin::Router::Resolver::VERSION = 0.01;

use Net::DNS;

use Moo;
use strictures 2;
use namespace::clean;

has res => (
            is      => 'ro',
            builder => sub {
              return Net::DNS::Resolver->new;
            }
           );

has err => ( is => 'rw' );

sub get_mx {
  my ($self, $domain) = @_;
  my @ips;
  $self->err('');

  my @mx = mx($self->res, $domain);

  if (@mx) {
    foreach my $rr (sort {$a->preference <=> $b->preference} @mx) {
      my @list = $self->get_ip($rr->exchange);
      if (@list) {
        push @ips, @list;
      }
    }
  }
  else {
    $self->err("Can not find MX records for $domain: " . $self->res->{errorstring});
  }

  return @ips;
}

sub get_ip {
  my ($self, $host) = @_;
  my @ips;
  $self->err('');

  my $reply = $self->res->search($host);

  if ($reply) {
    foreach my $rr ($reply->answer) {
      next unless ($rr->type eq "A" || $rr->type eq "AAAA");
      push @ips, $rr->address;
    }
  }
  else {
    $self->err("query failed: ". $self->res->{errorstring});
  }

  return @ips;
}

1;

=head1 NAME

  Qpsmtpd::Plugin::Router::Resolver - DNS wrapper module.

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::Resolver;
 my $dns = Qpsmtpd::Plugin::Router::Resolver->new(..);
 my @ip = $dns->get_ip($hostname);
 my @mx = $dns->get_mx($domain);

=head1 DESCRIPTION

Just a handy wrapper around Net::DNS with caching for faster response times.

=cut

