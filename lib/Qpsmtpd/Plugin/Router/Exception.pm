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

package Qpsmtpd::Plugin::Router::Exception;

$Qpsmtpd::Plugin::Router::Exception::VERSION = 0.01;

=head1 NAME

Qpsmtpd::Plugin::Router::Exception - QPRs own exception class

=head1 SYNOPSIS

 package X::Nix;
 use Carp;
 use Qpsmtpd::Plugin::Router::Exception;
 
 use Moo;
 
 Qpsmtpd::Plugin::Router::Exception->throw({msg => 'dont die while root'});
 Qpsmtpd::Plugin::Router::Exception->throw({final => 1, msg => 'give up'});
 croak "death by disruptor";
 

=head1 DESCRIPTION

General purpose exception  class, which makes it possible  to not only
die on errors, but die differently  depending on the type of error. As
an   SMTP  Router,   we   make  the   distinction  between   temporary
(i.e. "fixable") and final errors. So,  when some code die()'s then it
needs to tell  callers the cause and  if it's fixable or  not, so that
the  caller (the  router) can  decide if  it's worth  to re-queue  the
message or to discard it.

Usually  code just  calls ::throw({msg  => "what"}),  in which  case a
temporary exception will  be thrown.  That is,  the B<final> attribute
will be  FALSE, which makes it  temporary or fixable. If  you think an
error  shall  be the  end  of  a  transaction  then set  the  B<final>
attribute to a TRUE value.

The  convenient class  method C<e()>  is  able to  convert old  school
exceptions  into  ::Exception objects.   Since  a  classic die()  only
returns a string, e() cannot make any  decision of this is meant to be
final or not.  Therefore the  class' default applies, die() or croak()
errors are temporarily. This behavior is intended. If you want to turn
a die() into  a final error, you'll  need to catch and  re-throw it as
::Exception with the final flag enabled.

B<This is  a work in progress  as I'm still experimenting  how to make
this stuff best  from a caller and reader perspective,  so things will
change regularly>.

=cut


use Moo;
with 'Throwable';

has final   => (is=>'ro', default => 0);
has msg     => (is=>'ro', default => $@);

sub e {
  if (ref($_) eq 'Ex') {
    return $_;
  }
  else {
    chomp; return Qpsmtpd::Plugin::Router::Exception->new(msg => $_, type=>0);
  }
}





1;
