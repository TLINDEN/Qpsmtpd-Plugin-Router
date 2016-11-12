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

package Qpsmtpd::Plugin::Router::FS;

$Qpsmtpd::Plugin::Router::FS::VERSION = 0.01;


=head1 NAME

Qpsmtpd::Plugin::Router::FS - filesystem operations.

=head1 SYNOPSIS

 use Qpsmtpd::Plugin::Router::FS;
 my $fs = Qpsmtpd::Plugin::Router::FS->new(spooldir => $dir);
 my $ok = $fs->put($file, $data);
 print $fs->err if(! $ok);

 my $data = $fs->get($file);
 print $fs->err if(! $data);

=head1 DESCRIPTION

Securely create spool  files. Use proper nfs aware  locking, writes to
tmp file ini dest  dir first, then moves to new  name, if writing were
ok.

=head1 METHODS

=cut

use File::Temp;
use File::Spec::Functions qw(splitpath file_name_is_absolute catfile catpath);
use Fcntl qw(:DEFAULT :flock LOCK_EX LOCK_NB);
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);

use Moo;
use strictures 2;
use namespace::clean;

with 'Qpsmtpd::Plugin::Router::Role';

=head2 new(spooldir => $dir)

Return new FS instance.

=cut

has spooldir => ( is => 'rw' );

=head2 writable()

Check if spooldir is a directory and writable.

=cut

sub writable {
  my $self = shift;
  return -d $self->spooldir && -w $self->spooldir;
}

=head2 put($file, $data)

Write $data to $file within spooldir.

Actually writes  to a tmp file,  locks the destination file,  tries to
move the tmp file to it and removes the lock if all went well.

=cut

sub put {
  my($self, $file, $data) = @_;

  return 0 unless $self->writable;
  $self->rst;

  # 1st step, create temp file
  my $template = ".${file}.tmp.XXXX";
  my $fh = File::Temp->new(TEMPLATE => $template,
                           DIR      => $self->spooldir,
                           UNLINK   => 0);

  if (! $fh) {
    $self->err("Could not create tmp file: $!");
    return 0;
  }

  # ok, write data to tmp file
  my $filename = $fh->filename;
  print $fh $data;
  $fh->close();

  if ((stat($filename))[7] != length($data)) {
    $self->err("Something went horribly wrong while writing to $filename (file too small!)");
    return 0;
  }

  # all looks good so far, move it
  return $self->mv($self->spooldir, $filename, $self->spooldir, $file);
}

=head2 mv($srcdir, $srcfile, $dstdir, $dstfile)

Actually move a  file, does lots of checks before  doing so, locks the
file.

=cut

sub mv {
  my($self, $srcdir, $srcfile, $dstdir, $dstfile) = @_;
  $self->rst;
  my($src, $dst);

  if (file_name_is_absolute($srcfile)) {
    $src = $srcfile;
  }
  else {
    $src = catfile($srcdir, $srcfile);
  }

  if (file_name_is_absolute($dstfile)) {
    $dst = $dstfile;
  }
  else {
    $dst = catfile($dstdir, $dstfile);
  }

  if (!-d $dstdir) {
    $self->err("$dstdir does not exist or is not a directory");
    return 0;
  }

  if (!-w $dstdir) {
    $self->err("$dstdir is not writable");
    return 0;
  }

  if (!-r $src) {
    $self->err("$src does not exist or is not readable");
    return 0;
  }

  if (!-f $src) {
    $self->err("$src is not a file");
    return 0;
  }

  if (-r $dst) {
    $self->err("$dst already exists");
    return 0;
  }

  my $lock = $self->lock($dst);
  return unless($lock);

  my $ok = fmove($src, $dst);
  if (! $ok) {
    $self->err("Could not move file: $!");
  }

  $self->unlock($lock);
  return $ok;
}

=head2 lock($path)

Locks $path (does not need to exist).

Returns lock handle.

=cut

sub lock {
  my ( $self, $path ) = @_;

  open(my $lock, '>', "$path.lock") or do {
    $self->err("opening lockfile failed: $!");
    return;
  };

  flock($lock, LOCK_EX) or do {
    $self->err("flock of lockfile failed: $!");
    close $lock;
    return;
  };

  return $lock;
}

=head2 unlock($handle)

Unlock lock handle $handle.

=cut

sub unlock {
  my ( $self, $lock ) = @_;
  close $lock;
}



1;


