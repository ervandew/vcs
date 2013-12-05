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

if !exists('g:vcs_trac_loaded')
  let g:vcs_trac_loaded = 1
else
  finish
endif

function! vcs#impl#trac#GetLogUrl(root, file, args) " {{{
  return a:root . '/log/' . a:file . '?verbose=on'
endfunction " }}}

function! vcs#impl#trac#GetChangeSetUrl(root, file, args) " {{{
  return a:root . '/changeset/' . a:args[0]
endfunction " }}}

function! vcs#impl#trac#GetAnnotateUrl(root, file, args) " {{{
  let path = substitute(a:file, '/', '%2F', 'g')
  return a:root . '/' . a:file . '?annotate=1&rev=' . a:args[0]
endfunction " }}}

function! vcs#impl#trac#GetDiffUrl(root, file, args) " {{{
  let path = substitute(a:file, '/', '%2F', 'g')
  let r1 = path . '%40' . a:args[0]
  let r2 = path . '%40' . a:args[1]
  return a:root . printf('/changeset?new=%s&old=%s', r1, r2)
endfunction " }}}

" vim:ft=vim:fdm=marker
