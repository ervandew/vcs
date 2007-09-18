" Author:  Eric Van Dewoestine
" Version: $Revision$
"
" Description: {{{
"   Functions for working with version control systems.
"
" License:
"
" Copyright (c) 2005 - 2006
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"      http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.
"
" }}}

" ListDir(dir) {{{
function! eclim#vcs#log#ListDir (type, dir)
  let dir = a:dir

  if a:type == 'cvs'
    if exists('b:vcs_local_dir')
      let dir = strpart(
        \ b:vcs_local_dir, 0, stridx(b:vcs_local_dir, dir) + len(dir))
    endif

    let cwd = getcwd()
    exec 'lcd ' . dir
    try
      let listing = readfile('CVS/Entries')
    finally
      exec 'lcd ' . cwd
    endtry
  elseif a:type == 'svn'
    if exists('b:vcs_local_dir')
      let url = eclim#vcs#util#GetSvnReposUrl(b:vcs_local_dir) . dir
    else
      let url = eclim#vcs#util#GetSvnUrl(dir, '')
    endif
    let listing = split(system('svn list ' . url), '\n')
  else
    call eclim#util#EchoError('Current file is not under cvs or svn version control.')
    return
  endif

  let lines = listing

  call s:TempWindow(lines)
endfunction " }}}

" Log(dir, file) {{{
function! eclim#vcs#log#Log (dir, file)
  let file = a:dir != '' ? a:file : expand('%:p:t')
  let dir = a:dir != '' ? a:dir : expand('%:p:h')

  let cwd = getcwd()
  exec 'lcd ' . dir

  try
    if isdirectory(dir . '/CVS')
      let type = 'cvs'
      let result = system('cvs log -l "' . file . '"')
      let log = s:ParseCvsLog(split(result, '\n'))
    elseif isdirectory(dir . '/.svn')
      let type = 'svn'
      let result = system('svn log "' . file . '"')
      let log = s:ParseSvnLog(split(result, '\n'))
    else
      call eclim#util#EchoError('Current file is not under cvs or svn version control.')
      return
    endif
  finally
    exec 'lcd ' . cwd
  endtry

  let path = split(eclim#vcs#util#GetPath(dir, file), '/')
  let head = map(path[:-2], '"|" . v:val . "|"')
  let lines = [join(head, ' / ') . ' / ' . path[-1], '']
  let index = 0
  for entry in log
    let index += 1
    call add(lines, '------------------------------------------')
    if type == 'cvs'
      call add(lines, 'Revision: ' . entry.revision . ' |view| |annotate|')
    else
      call add(lines, 'Revision: |' . entry.revision . '| |view| |annotate|')
    endif
    call add(lines, 'Modified: ' . entry.date . ' by ' . entry.author)
    if index < len(log)
      call add(lines, 'Diff: |previous ' . log[index].revision . '|')
    endif
    call add(lines, '')
    let lines += entry.comment
    if lines[-1] !~ '^\s*$' && index != len(log)
      call add(lines, '')
    endif
  endfor

  call s:TempWindow(lines)

  let b:vcs_local_dir = dir
  let b:vcs_type = type

  set ft=vcs_log
  hi link VcsDivider Constant
  hi link VcsHeader Identifier
  hi link VcsLink Label
  " TODO: highlight path and make linkable
  hi link VcsPathLink Label
  syntax match VcsDivider /^-\+$/
  syntax match VcsLink /|.\{-}|/
  syntax match VcsHeader /^\(Revision\|Modified\):/

  nnoremap <silent> <buffer> <cr> :call <SID>FollowLink()<cr>
endfunction " }}}

" s:ParseCvsLog() {{{
" Parse the cvs log.
function! s:ParseCvsLog (lines)
  let log = []
  let section = 'head'
  for line in a:lines
    if line =~ '^=\+$'
      continue
    elseif line =~ '^-\+$'
      let section = 'info'
      let entry = {'comment': []}
      call add(log, entry)
      continue
    elseif section == 'head'
      continue
    elseif section == 'info'
      if line =~ '^revision'
        let entry['revision'] = substitute(line, 'revision\s\(.*\)', '\1', '')
      elseif line =~ '^date:'
        let entry['author'] = substitute(line, '.*author:\s*\(.\{-}\);.*', '\1', '')
        let entry['date'] = substitute(line, '.*date:\s*\(.\{-}\);.*', '\1', '')
        let entry['date'] = substitute(entry.date, '/', '-', 'g')
        let section = 'comment'
      endif
    elseif section == 'comment'
      call add(entry.comment, line)
    endif
  endfor
  return log
endfunction " }}}

" s:ParseSvnLog() {{{
" Parse the svn log.
function! s:ParseSvnLog (lines)
  let log = []
  let section = 'head'
  let index = 0
  for line in a:lines
    let index += 1
    if line =~ '^-\+$' && index == len(a:lines)
      " get rid of empty line at the end of last entry's comment
      if exists('l:entry') && entry.comment[-1] =~ '^\s*$'
        let entry.comment = entry.comment[:-2]
      endif
      continue
    elseif line =~ '^-\+$'
      " get rid of empty line at the end of entry's comment
      if exists('l:entry') && entry.comment[-1] =~ '^\s*$'
        let entry.comment = entry.comment[:-2]
      endif
      let section = 'info'
      let entry = {'comment': []}
      call add(log, entry)
      continue
    elseif section == 'head'
      continue
    elseif section == 'info'
      let entry['revision'] = substitute(line, '^r\(\w\+\).*', '\1', '')
      let entry['author'] = substitute(line, '.\{-}|\s*\(\w\+\)\s*|.*', '\1', '')
      let entry['date'] = substitute(line, '.\{-}|.\{-}|\s*\(.\{-}\)\s\+[+-].\{-}|.*', '\1', '')
      let section = 'comment'
    elseif section == 'comment'
      " ignore leading blank line of comment section
      if len(entry.comment) == 0 && line =~ '^\s*$'
        continue
      endif
      call add(entry.comment, line)
    endif
  endfor
  return log
endfunction " }}}

" s:FollowLink () {{{
function! s:FollowLink ()
  let line = getline('.')
  let link = substitute(
    \ getline('.'), '.*|\(.\{-}\%' . col('.') . 'c.\{-}\)|.*', '\1', '')
  if link == line
    return
  endif

  echom link
  " link to svn folder
  if line('.') == 1
    let path = substitute(
      \ getline('.'), '\(.*|.\{-}\%' . col('.') . 'c.\{-}\)|.*', '\1', '')
    let path = substitute(path, '\(| / |\||\)', '/', 'g')

    call eclim#vcs#log#ListDir(b:vcs_type, path)

  " link to view a change set
  elseif link =~ '^[0-9.]\+$'
    " changeset: svn log -vr <revision>

  " link to annotate a file
  elseif link == 'annotate'

  " link to view a file
  elseif link == 'view'

  " link to diff a file
  elseif link =~ '^previous [0-9.]\+$'

  endif
endfunction " }}}

" s:TempWindow (lines) {{{
function! s:TempWindow (lines)
  let filename = expand('%:p')
  if expand('%') == '[vcs_log]' && exists('b:filename')
    let filename = b:filename
  endif

  call eclim#util#TempWindow('[vcs_log]', a:lines)

  let b:filename = filename
  augroup temp_window
    autocmd! BufUnload <buffer>
    call eclim#util#GoToBufferWindowRegister(b:filename)
  augroup END
endfunction " }}}

" vim:ft=vim:fdm=marker