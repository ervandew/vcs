" Author:  Eric Van Dewoestine
"
" License: {{{
"   Copyright (c) 2005 - 2024, Eric Van Dewoestine
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

function! vcs#editor#ViewDiff() " {{{
  let GetEditorFile = vcs#util#GetVcsFunction('GetEditorFile')
  if type(GetEditorFile) != 2
    return
  endif

  let file = GetEditorFile()
  if file != ''
    let winend = winnr('$')
    let winnum = 1
    while winnum <= winend
      let bufnr = winbufnr(winnum)
      if getbufvar(bufnr, 'vcs_editor_diff') != '' ||
         \ getbufvar(bufnr, 'vcs_diff_temp') != ''
        exec bufnr . 'bd'
        continue
      endif
      let winnum += 1
    endwhile

    exec 'belowright sview ' . escape(file, ' ')
    let b:vcs_editor_diff = 1
    autocmd BufEnter <buffer> nested call s:CloseIfLastWindow()

    " if file is versioned, execute VcsDiff
    let path = substitute(expand('%:p'), '\', '/', 'g')
    let revision = vcs#util#GetRevision(path)
    if revision != ''
      let status = vcs#util#GetStatus(path)
      " should be when ammending a commit and the file wasn't modified
      if status == ''
        VcsDiff prev
      else
        VcsDiff
      endif
      autocmd BufEnter <buffer> nested call s:CloseIfLastWindow()
    endif
  endif
endfunction " }}}

function! s:CloseIfLastWindow() " {{{
  " if nothing but differ buffers are open, then close vim.
  let winend = winnr('$')
  let winnum = 1
  while winnum <= winend
    let bufnr = winbufnr(winnum)
    if getbufvar(bufnr, 'vcs_editor_diff') == '' &&
       \ getbufvar(bufnr, 'vcs_diff_temp') == ''
      return
    endif
    let winnum += 1
  endwhile
  quitall
endfunction " }}}

" vim:ft=vim:fdm=marker
