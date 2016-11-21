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

package Qpsmtpd::Plugin::Router::Serialize;

$Qpsmtpd::Plugin::Router::Serialize::VERSION = 0.01;


=head1 NAME

Qpsmtpd::Plugin::Router::Serialize - serialize Qpsmtpd::Transaction objects to disk.

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::Serialize;
 my $serializer = Qpsmtpd::Plugin::Router::Serialize->new(..);

 my $ok = $serializer->freeze($transaction, $file);

 my $ok = $serializer->thaw($file, $transaction);

=head1 DESCRIPTION

Write Qpsmtpd::Transaction objects to disk,  support NFS locking, use a
temporary file in  the same directory and only move  to final filename
when write ok. Do the reverse on thaw().

=head1 METHODS

=cut

use Qpsmtpd::Transaction;
use Qpsmtpd::Plugin::Router::FS;
use Storable qw(freeze thaw);
use Safe;
use File::Spec::Functions qw(splitpath file_name_is_absolute catfile catpath);

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Role';

=head2 new()

New serializer.

=cut



has fs => (
           is      => 'rw',
           default => Qpsmtpd::Plugin::Router::FS->new()
          );


sub BUILD {
  my ($self, $args) = @_;
  my $safe = Safe->new();
  $safe->permit(qw(:default require));
  local $Storable::Deparse = 1;
  local $Storable::Eval = sub { $safe->reval($_[0]) };
}

=head2 conserve($transaction, $file)

Serialize   $transaction  (assumed   to  be   an  Qpsmtpd::Transaction
instance) to $file, which must be absolute.

=cut

sub conserve {
  my($self, $transaction, $file) = @_;

  my $dump = freeze($transaction);

  return $self->fs->put($file, $dump);
}

=head2 restore($file)

Deserialize from $file, return transaction object.

=cut

sub restore {
  my($self, $file) = @_;

  my $code = $self->fs->get($file);
  my $transaction = thaw($code);

  if (!$transaction) {
    die("failed to thaw() from $file: $!");
  }

  return $transaction;
}

=head2 set_spool($file)

Set FS  spooldir from directory  of $file  path.  Must be  called with
$file before conserve() or restore() if $self has an empty FS object.

=cut

sub set_spool {
  my($self, $file) = @_;
  my($vol, $dir, $queuefile) = splitpath($file);
  $self->fs->spooldir(catpath($vol, $dir));
}

1;
