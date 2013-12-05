" Author:  Eric Van Dewoestine
"
" License: {{{
"   Copyright (c) 2005 - 2013, Eric Van Dewoestine
"   All rights reserved.
"
"   Redistribution and use of this software in source and binary forms, with
"   or without modification, are permitted provided that the following
"   conditions are met:
"
"   * Redistributions of source code must retain the above
"     copyright notice, this list of conditions and the
"     following disclaimer.
"
"   * Redistributions in binary form must reproduce the above
"     copyright notice, this list of conditions and the
"     following disclaimer in the documentation and/or other
"     materials provided with the distribution.
"
"   * Neither the name of Eric Van Dewoestine nor the names of its
"     contributors may be used to endorse or promote products derived from
"     this software without specific prior written permission of
"     Eric Van Dewoestine.
"
"   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
"   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
"   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
"   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
"   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
"   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
"   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
"   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
"   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
"   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
"   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
" }}}

if !exists('g:vcs_bitbucket_loaded')
  let g:vcs_bitbucket_loaded = 1
else
  finish
endif

function! vcs#impl#bitbucket#GetSettings(origin) " {{{
  let project = substitute(a:origin, '.*\<bitbucket\.org/\(.\{-}\)', '\1', '')
  if vcs#util#GetVcsType() == 'git'
    let project = substitute(project, '\.git$', '', '')
  endif
  let url = 'https://bitbucket.org/' . project
  return {
    \ 'web_viewer': 'bitbucket',
    \ 'web_url': url,
    \ 'tracker_url': url . '/issue/<id>'
  \ }
endfunction " }}}

function! vcs#impl#bitbucket#GetLogUrl(root, file, args) " {{{
  return a:root . '/history-node/' . a:args[0] . '/' . a:file
endfunction " }}}

function! vcs#impl#bitbucket#GetChangeSetUrl(root, file, args) " {{{
  let revision = a:args[0] =~ ':' ? split(a:args[0], ':')[1] : a:args[0]
  return a:root . '/changeset/' . revision
endfunction " }}}

function! vcs#impl#bitbucket#GetAnnotateUrl(root, file, args) " {{{
  let revision = a:args[0] =~ ':' ? split(a:args[0], ':')[1] : a:args[0]
  return a:root . '/annotate/' . revision . '/' . a:file
endfunction " }}}

function! vcs#impl#bitbucket#GetDiffUrl(root, file, args) " {{{
  let r1 = a:args[0] =~ ':' ? split(a:args[0], ':')[1] : a:args[0]
  let r2 = a:args[1] =~ ':' ? split(a:args[1], ':')[1] : a:args[1]
  return a:root . '/diff/' . a:file . '?diff1=' . r1 . '&diff2=' . r2
endfunction " }}}

" vim:ft=vim:fdm=marker
