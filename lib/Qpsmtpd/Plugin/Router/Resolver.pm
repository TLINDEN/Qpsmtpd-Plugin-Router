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

=head1 NAME

  Qpsmtpd::Plugin::Router::Resolver - DNS wrapper module.

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::Resolver;
 my $dns = Qpsmtpd::Plugin::Router::Resolver->new();
 my @ip = $dns->get_ip($hostname);
 my @mx = $dns->get_mx($domain);

=head1 DESCRIPTION

Just a handy wrapper around Net::DNS with caching for faster response times.

=head1 METHODS

=cut

use Net::DNS;
use Data::Validate::IP qw(is_ipv4 is_ipv6);

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Role';

=head2 new()

New caching resolver lib.

=cut

has res => (
            is      => 'ro',
            builder => sub {
              return Net::DNS::Resolver->new;
            }
           );

=head2 get_mx($domain)

Resolve MX record(s) for a domain.

Returns a list of ip addresses ordered by MX priority.

Last entry of the list is the A record of the domain, if any.

=cut

sub get_mx {
  my ($self, $domain) = @_;
  my @ips;
  $self->rst;

  my @mx = mx($self->res, $domain);

  if (@mx) {
    foreach my $rr (sort {$a->preference <=> $b->preference} @mx) {
      my @list = $self->get_ip($rr->exchange);
      if (@list) {
        push @ips, @list;
      }
    }
  }

  my @a = $self->get_ip($domain);
  if (@a) {
    push @mx, @a;
  }

  if (! @mx) {
    $self->err("Can not find MX records for $domain: " . $self->res->{errorstring});
  }

  return @ips;
}

=head2 get_ip($host)

Resolve $host. Returns a list of ip addresses.

=cut

sub get_ip {
  my ($self, $host) = @_;
  my @ips;
  $self->rst;

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

=head2 parse("host:port,...")

Parse a given  host argument (list). Checks if a  port has been given,
checks if an ip address is valid and if a hostname is resolvable.

Returns array-ref of {host => $host, port => $port}

=cut

sub parse {
  my ($self, $list) = @_;
  $self->rst;
  my @servers;

  foreach my $entry (split /\s*,\s*/, $list) {
    my ($host, $port);
    if ($entry =~ /\[([^\]]*)(.*)/ || $entry =~ /([^:]*)(.*)/) {
      # v6
      $host = $1;
      $port = $2 || 25;
      $port =~ s/://;

      # host ok (v4, v6, name)?
      if (! is_ipv6($host)) {
        if (! is_ipv4($host)) {
          if (! $self->get_ip($host)) {
            return (); # err already set by get_ip()
          }
        }
      }

      # port ok?
      if ($port < 1 || $port > 65535) {
        $self->err("Invalid port ($host:$port)!");
        return ();
      }

      # use
      push @servers, {host => $host, port => $port};
    }
  }

  return @servers;
}

1;

