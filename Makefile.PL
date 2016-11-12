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
#
# Makefile.PL - build file for Qpsmtpd::Plugin::Router
#

use ExtUtils::MakeMaker;

WriteMakefile(
              NAME         => 'Qpsmtpd::Plugin::Router',
              VERSION_FROM => 'lib/Qpsmtpd/Plugin/Router.pm',
              ABSTRACT     => 'qpsmtpd general purpose policy mail router / spooler',
              LICENSE      => 'perl',
              AUTHOR       => 'Thomas v.Dein <tlinden@cpan.org>',
              clean        => { FILES => '*~ */*~' },
              PREREQ_PM    => {
                               'Crypt::Random'         => 0,
                               'File::Temp'            => 0,
                               'Moo'                   => 0,
                               'File::Copy::Recursive' => 0,
                               'File::Temp'            => 0,
                               'Fcntl'                 => 0,
                               'File::Spec'            => 0,
                               'strictures'            => 0
                              },
              dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
              test         => { TESTS => 't/*.t' },
              'META_MERGE' => {
                               resources => {
                                             repository => 'https://github.com/TLINDEN/Qpsmtpd-Plugin-Router',
                                            },
                              },

             );

