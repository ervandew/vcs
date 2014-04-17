" Author:  Eric Van Dewoestine
"
" License: {{{
"   Copyright (c) 2005 - 2014, Eric Van Dewoestine
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

if !exists('g:vcs_hg_loaded')
  let g:vcs_hg_loaded = 1
else
  finish
endif

" Script Variables {{{
  let s:trackerIdPattern = join(vcs#command#VcsTrackerIdPatterns, '\|')
  let s:path = substitute(expand('<sfile>:h'), '\', '/', 'g')
" }}}

function! vcs#impl#hg#GetAnnotations(path, revision) " {{{
  let cmd = 'annotate -uncd'
  if a:revision != ''
    let revision = substitute(a:revision, '.*:', '', '')
    let cmd .= ' -r ' . revision
  endif
  let result = vcs#impl#hg#Hg(cmd . ' "' . a:path . '"')
  if type(result) == 0
    return
  endif

  let annotations = split(result, '\n')
  call map(annotations,
      \ "substitute(v:val, '^\\s*\\(.*\\)\\s\\d\\+\\s\\(\\w\\+\\)\\s\\(.\\{-}\\):\\s.*', '\\2 (\\3) \\1', '')")

  return annotations
endfunction " }}}

function! vcs#impl#hg#GetPreviousRevision(path, ...) " {{{
  " Optional args:
  "   revision

  let cmd = 'log -f -q --template "{node|short}\n"'
  if len(a:000) > 0 && a:000[0] != ''
    let cmd .= ' -r' . a:000[0] . ':1'
  endif
  let log = vcs#impl#hg#Hg(cmd . ' --limit 2 "' . a:path . '"')
  if type(log) == 0
    return
  endif
  let revisions = split(log, '\n')
  return len(revisions) > 1 ? revisions[1] : 0
endfunction " }}}

function! vcs#impl#hg#GetRevision(path) " {{{
  let log = vcs#impl#hg#Hg('log -f -q --template "{node|short}\n" --limit 1 "' . a:path . '"')
  if type(log) == 0
    return
  endif
  return substitute(log, '\n', '', '')
endfunction " }}}

function! vcs#impl#hg#GetRevisions() " {{{
  let revs = []

  let result = vcs#impl#hg#Hg('tags')
  if type(result) != 0
    let tags = split(result, '\n')
    call map(tags, "substitute(v:val, '^\\(.\\{-}\\)\\s.*$', '\\1', '')")
    call extend(revs, tags)
  endif

  let result = vcs#impl#hg#Hg('branches')
  if type(result) != 0
    let branches = split(result, '\n')
    call map(branches, "substitute(v:val, '^\\(.\\{-}\\)\\s.*$', '\\1', '')")
    call extend(revs, branches)
  endif

  call sort(revs)
  return revs
endfunction " }}}

function! vcs#impl#hg#GetOrigin() " {{{
  return substitute(vcs#impl#hg#Hg('showconfig paths.default'), '\n$', '', '')
endfunction " }}}

function! vcs#impl#hg#GetRoot() " {{{
  let root = vcs#impl#hg#Hg('root')
  if type(root) == 0
    return
  endif
  let root = substitute(root, '\n', '', '')
  let root = substitute(root, '\', '/', 'g')
  return root
endfunction " }}}

function! vcs#impl#hg#GetInfo() " {{{
  let branch = substitute(vcs#impl#hg#Hg('branch'), '\n$', '', '')
  if branch == '0'
    return ''
  endif

  let bmarks = split(vcs#impl#hg#Hg('bookmarks'), '\n')
  let bmarks = filter(bmarks, 'v:val =~ "^\\s*\\*"')
  let bmark = len(bmarks) == 1 ?
    \ substitute(bmarks[0], '^\s*\*\s*\(\w\+\)\s.*', '\1', '') : ''
  let info = 'hg:' . branch . (bmark != '' ? (':' . bmark) : '')
  return info
endfunction " }}}

function! vcs#impl#hg#GetEditorFile() " {{{
  let line = getline('.')
  let file = ''
  if line =~ '^HG: changed .*'
    let file = substitute(line, '^HG: changed\s\+\(.*\)\s*', '\1', '')
  elseif line =~ '^HG: added .*'
    let file = substitute(line, '^HG: added\s\+\(.*\)\s*', '\1', '')
  endif
  return file
endfunction " }}}

function! vcs#impl#hg#GetModifiedFiles() " {{{
  let status = vcs#impl#hg#Hg('status -m -a -u -n')
  let root = vcs#impl#hg#GetRoot()
  return map(split(status, "\n"), 'root . "/" . v:val')
endfunction " }}}

function! vcs#impl#hg#Info(path) " {{{
  let result = vcs#impl#hg#Hg('log -f --limit 1 "' . a:path . '"')
  if type(result) == 0
    return
  endif
  call vcs#util#Echo(result)
endfunction " }}}

function! vcs#impl#hg#Log(args, ...) " {{{
  " Optional args:
  "   exec: non-0 to run the command with exec

  " Note: tags are space separated, so if the user has a space in their tag
  " name, that tag will be screwed in the log.
  let logcmd = 'log -f --template "{node|short}|{author}|{date|age}|{tags}|{desc|firstline}\n"'
  if g:VcsLogMaxEntries > 0
    let logcmd .= ' --limit ' . g:VcsLogMaxEntries
  endif
  if a:args != ''
    let logcmd .= ' ' . a:args
  endif

  let exec = len(a:000) > 0 ? a:000[0] : 0
  let result = vcs#impl#hg#Hg(logcmd, exec)
  if type(result) == 0
    return
  endif
  let log = []
  for line in split(result, '\n')
    let values = split(line, '|')
    call add(log, {
        \ 'revision': values[0],
        \ 'author': values[1],
        \ 'age': values[2],
        \ 'refs': split(values[3]),
        \ 'comment': values[4],
     \ })
  endfor
  let root_dir = exists('b:vcs_props') ?
    \ b:vcs_props.root_dir : vcs#impl#hg#GetRoot()
  return {'log': log, 'props': {'root_dir': root_dir}}
endfunction " }}}

function! vcs#impl#hg#LogGrep(pattern, args, type) " {{{
  if a:type == 'files'
    let result = vcs#impl#hg#Hg('grep --all "' . a:pattern . '" ' . a:args, 1)
    if type(result) == 0
      return
    endif
    let revisions = []
    for line in split(result, '\n')
      let revision = split(line, ':')[1]
      if index(revisions, revision) == -1
        call add(revisions, revision)
      endif
    endfor
    if len(revisions) == 0
      let root_dir = exists('b:vcs_props') ?
        \ b:vcs_props.root_dir : vcs#impl#hg#GetRoot()
      return {'log': [], 'props': {'root_dir': root_dir}}
    endif
    return vcs#impl#hg#Log('-r ' . join(revisions, ' -r ') . ' ' . a:args)
  endif

  return vcs#impl#hg#Log('-k "' . a:pattern . '" ' . a:args, 1)
endfunction " }}}

function! vcs#impl#hg#LogDetail(revision) " {{{
  let logcmd = 'log "--template=' .
    \ '{node|short}|{author}|{date|age}|{date|isodate}|{tags}|{desc|firstline}|{desc}"'
  let result = vcs#impl#hg#Hg(logcmd . ' -r ' . a:revision)
  if type(result) == 0
    return
  endif
  let values = split(result, '|')
  return {
      \ 'revision': values[0],
      \ 'author': values[1],
      \ 'age': values[2],
      \ 'date': values[3],
      \ 'refs': split(values[4]),
      \ 'comment': values[5],
      \ 'description': values[6],
   \ }
endfunction " }}}

function! vcs#impl#hg#LogFiles(revision) " {{{
  let logcmd = 'log --copies "--style=' . s:path .  '/hg_log_files.style" '
  let result = vcs#impl#hg#Hg(logcmd . '-r ' . a:revision)
  if type(result) == 0
    return
  endif
  let files = []
  let deletes = []
  for result in split(result, '\n')
    if result =~ 'R'
      let [status, old, new] = split(result, '\t')
      " filter out copies (the --copies arg shows cp and mv ops)
      if index(deletes, old) == -1
        continue
      else
        call remove(files, index(files, {'status': 'D', 'file': old}))
        call remove(files, index(files, {'status': 'A', 'file': new}))
      endif
      call add(files, {'status': status, 'old': old, 'new': new})
    else
      let [status, file] = split(result, '\t')
      " keep this list for filtering out copies
      if status == 'D'
        call add(deletes, file)
      endif
      call add(files, {'status': status, 'file': file})
    endif
  endfor
  return files
endfunction " }}}

function! vcs#impl#hg#ViewFileRevision(path, revision) " {{{
  let revision = substitute(a:revision, '.\{-}:', '', '')
  let result = vcs#impl#hg#Hg('cat -r ' . revision . ' "' . a:path . '"')
  return split(result, '\n')
endfunction " }}}

function! vcs#impl#hg#ViewCommitPatch(revision) " {{{
  let result = vcs#impl#hg#Hg('log -l 1 -p -r ' . a:revision)
  return split(result, '\n')
endfunction " }}}

function! vcs#impl#hg#Hg(args, ...) " {{{
  " Optional args:
  "   exec: non-0 to run the command with exec
  let exec = len(a:000) > 0 && a:000[0]
  return vcs#util#Vcs('hg', a:args, exec)
endfunction " }}}

" vim:ft=vim:fdm=marker
