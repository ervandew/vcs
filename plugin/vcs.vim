" Author:  Eric Van Dewoestine
"
" Description: {{{
"   Commands for working with version control systems.
" }}}
"
" License: {{{
"   Copyright (c) 2005 - 2010, Eric Van Dewoestine
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

if v:version < 700
  finish
endif

let s:save_cpo=&cpo
set cpo&vim

" Global Variables {{{

if !exists('g:VcsRepositorySettings')
  let g:VcsRepositorySettings = {}
endif

" }}}

" Autocmds {{{

autocmd BufRead hg-editor-* set ft=hg
autocmd BufRead COMMIT_EDITMSG set ft=gitcommit

" }}}

" Command Declarations {{{
if !exists(":VcsLog")
  command -nargs=* VcsLog
    \ if s:CheckWindow() |
    \   call vcs#command#Log(<q-args>) |
    \ endif
  command -nargs=* VcsLogGrepMessage call vcs#command#LogGrep(<q-args>, 'message')
  command -nargs=* VcsLogGrepFiles call vcs#command#LogGrep(<q-args>, 'files')
  command -nargs=? VcsDiff
    \ if s:CheckWindow() |
    \   call vcs#command#Diff('<args>') |
    \ endif
  command -nargs=? VcsCat
    \ if s:CheckWindow() |
    \   call vcs#command#ViewFileRevision(expand('%:p'), '<args>', 'split') |
    \ endif
  command VcsAnnotate :call vcs#command#Annotate()
  command -nargs=0 VcsInfo
    \ if s:CheckWindow() |
    \   call vcs#command#Info() |
    \ endif
endif

if !exists(":VcsWebLog")
  command -nargs=? -complete=customlist,vcs#util#CommandCompleteRevision
    \ VcsWebLog call vcs#web#VcsWebLog(<q-args>)
  command -nargs=? -complete=customlist,vcs#util#CommandCompleteRevision
    \ VcsWebChangeSet call vcs#web#VcsWebChangeSet(<q-args>)
  command -nargs=? -complete=customlist,vcs#util#CommandCompleteRevision
    \ VcsWebAnnotate call vcs#web#VcsWebAnnotate(<q-args>)
  command -nargs=* -complete=customlist,vcs#util#CommandCompleteRevision
    \ VcsWebDiff call vcs#web#VcsWebDiff(<q-args>)
endif

function! s:CheckWindow()
  return &buftype == ''
endfunction

" }}}

let &cpo = s:save_cpo

" vim:ft=vim:fdm=marker
