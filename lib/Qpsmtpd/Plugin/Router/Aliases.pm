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


package Qpsmtpd::Plugin::Router::Aliases;

$Qpsmtpd::Plugin::Router::Aliases::VERSION = 0.01;

=head1 NAME

Qpsmtpd::Plugin::Router::Aliases - alias file parser and matcher

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::Aliases;
 my $router = Qpsmtpd::Plugin::Router::Aliases->new(aliasesfiles => [files]);

=head1 DESCRIPTION

Parse give  aliases file(s)  and provide methods  to match  an address
against it.

=head1 Aliases FILE

Filename  containing  recipient user  to  unix  user mapping,  without
domains. This  file is  B<required> if local  delivery (using  the MDA
agent) is being used.

Format:

 virtual-user    unix-user

There  B<must> be  an entry  for root,  since the  MDA agent  will NOT
deliver mails to  the root user directly, e.g.:

 root    max

Also there B<must> be an entry  for EVERY valid recipient, but you can
use regular expressions on the virtual side, e.g.:

 .*master    admin
 .*www.*     phpgroup

=head1 METHODS

=cut

use Qpsmtpd::Plugin::Router::Policy;
use Qpsmtpd::Plugin::Router::Exception;
use FileHandle;

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Role';

=head new(aliasfiles => [])

Parse   given  aliases   file   and  return   a   new  Alias   matcher
object. The aliasfiles parameter is mandatory.

=cut

has aliasfiles => (
                   is       => 'rw',
                   required => 1,
                   traits => ['Array'],
                   isa      => sub {
                     if (defined $_[0]) {
                       foreach my $aliasfile (@{$_[0]}) {
                         if (! -r $aliasfile) {
                           die "Alias file $aliasfile does not exist or is not readable!";
                         }
                       }
                     }
                     else {
                       die "Please provide one or more alias files!";
                     }
                   },
                  );

sub BUILD {
  my ($self, $args) = @_;
  $self->_parse_aliases;
}

#
# internal: alias file parser, sets $self->aliases array ref
# which consists of: { regex => $regex, user => $user }
sub _parse_aliases {
  my ($self) = @_;
  my @aliases;

  my $fh = FileHandle->new;

  foreach my $aliasfile (@{$self->aliasfiles}) {
    if ($fh->open("<" . $aliasfile)) {
      while (<$fh>) {
        chomp;
        next if(/^\s*$/ || /^\s*#/);
        my($if, $then) =  split /\s\s*/, $_, 2;
        push @aliases, { regex => Qpsmtpd::Plugin::Router::Policy::_rule_p($self, $if),
                         user  => $then };
      }
      $fh->close();

    }
    else {
      die "Could not read " . $aliasfile . ": $!\n";
    }
  }

  $self->aliases(\@aliases);
}


=head2 mail2user($address)

Return local user for given email address, if any.

=cut

sub mail2user {
  my($self, $address) = @_;

  foreach my $rule (@{$self->aliases}) {
    if ($address =~ /$rule->{regex}/x) {
      return $rule->{user};
    }
  }

  return 0; # no match
}

1;
