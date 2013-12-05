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

if !exists('g:vcs_hgserve_loaded')
  let g:vcs_hgserve_loaded = 1
else
  finish
endif

function! vcs#impl#hgserve#GetLogUrl(root, file, args) " {{{
  "let revision = a:args[0] =~ ':' ? split(a:args[0], ':')[1] : a:args[0]
  "return a:root . '/log/' . revision . '/' . a:file
  return a:root . '/log/tip/' . a:file
endfunction " }}}

function! vcs#impl#hgserve#GetChangeSetUrl(root, file, args) " {{{
  let revision = a:args[0] =~ ':' ? split(a:args[0], ':')[1] : a:args[0]
  return a:root . '/rev/' . revision
endfunction " }}}

function! vcs#impl#hgserve#GetAnnotateUrl(root, file, args) " {{{
  let revision = a:args[0] =~ ':' ? split(a:args[0], ':')[1] : a:args[0]
  return a:root . '/annotate/' . revision . '/' . a:file
endfunction " }}}

function! vcs#impl#hgserve#GetDiffUrl(root, file, args) " {{{
  let r1 = a:args[0] =~ ':' ? split(a:args[0], ':')[1] : a:args[0]
  " hgserve doesn't support diffing arbitrary revisions
  "let r1 = a:args[1] =~ ':' ? split(a:args[1], ':')[1] : a:args[1]
  return a:root . '/diff/' . r1 . '/' . a:file
endfunction " }}}

" vim:ft=vim:fdm=marker
