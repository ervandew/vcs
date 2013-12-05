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

if !exists('g:vcs_git_loaded')
  let g:vcs_git_loaded = 1
else
  finish
endif

" Autocmds {{{

augroup vcs_git
  autocmd BufReadCmd index_blob_* call <SID>ReadIndex()
augroup END

" }}}

" Script Variables {{{
  let s:trackerIdPattern = join(vcs#command#VcsTrackerIdPatterns, '\|')
" }}}

function! vcs#impl#git#GetAnnotations(path, revision) " {{{
  let cmd = 'annotate'
  let revision = ''
  if a:revision != ''
    let revision = ' ' . substitute(a:revision, '.*:', '', '')
  endif
  let result = vcs#impl#git#Git(cmd . ' "' . a:path . '"' . revision)
  if type(result) == 0
    return
  endif

  let annotations = split(result, '\n')
  call map(annotations,
      \ "substitute(v:val, '\\(.\\{-}\\)\\s\\+(\\s*\\(.\\{-}\\)\\s\\+\\(\\d\\{4}-\\d\\{2}\-\\d\\{2}\\s.\\{-}\\)\\s\\+[0-9]\\+).*', '\\1 (\\3) \\2', '')")
  " substitute(v:val, '\\(.\\{-}\\)\\s\\+(.*', '\\2 (\\3) \\1', '')")
  call map(annotations, "v:val =~ '^0\\{5,}' ? 'uncommitted' : v:val")

  return annotations
endfunction " }}}

function! vcs#impl#git#GetPreviousRevision(path, ...) " {{{
  " Optional args:
  "   revision

  let revision = 'HEAD'
  if len(a:000)
    let revision = a:000[0]
  endif

  let cmd = 'rev-list --abbrev-commit -n 1 --skip=1 ' . revision . ' -- "' . a:path . '"'
  let prev = vcs#impl#git#Git(cmd)
  if type(prev) == 0
    return
  endif
  return substitute(prev, '\n', '', 'g')
endfunction " }}}

function! vcs#impl#git#GetRevision(path) " {{{
  " for some reason, in some contexts (git commit buffer), the git command
  " will fail if not run from root of the repos.
  let root = vcs#impl#git#GetRoot()
  exec 'lcd ' . escape(root, ' ')

  let path = a:path

  " kind of a hack to support diffs against git's staging (index) area.
  if path =~ '\<index_blob_[a-z0-9]\{40}_'
    let path = substitute(path, '\<index_blob_[a-z0-9]\{40}_', '', '')
  endif

  let rev = vcs#impl#git#Git('rev-list --abbrev-commit -n 1 HEAD -- "' . path . '"')
  if type(rev) == 0
    return
  endif
  return substitute(rev, '\n', '', '')
endfunction " }}}

function! vcs#impl#git#GetRevisions() " {{{
  let revs = []

  let result = vcs#impl#git#Git('tag -l')
  if type(result) != 0
    call extend(revs, split(result, '\n'))
  endif

  let result = vcs#impl#git#Git('branch -r')
  if type(result) != 0
    let branches = split(result, '\n')
    call map(branches, "substitute(v:val, '^.*/\\(.*\\)$', '\\1', '')")
    call extend(revs, branches)
  endif

  call sort(revs)
  return revs
endfunction " }}}

function! vcs#impl#git#GetOrigin() " {{{
  return substitute(vcs#impl#git#Git('config --get remote.origin.url'), '\n$', '', '')
endfunction " }}}

function! vcs#impl#git#GetRoot() " {{{
  " try submodule first
  let submodule = findfile('.git', escape(getcwd(), ' ') . ';')
  if submodule != '' && readfile(submodule, '', 1)[0] =~ '^gitdir:'
    return fnamemodify(submodule, ':p:h')
  endif

  " try standard .git dir
  let root = finddir('.git', escape(getcwd(), ' ') . ';')
  if root == ''
    return
  endif
  let root = fnamemodify(root, ':p:h:h')
  let root = substitute(root, '\', '/', 'g')
  return root
endfunction " }}}

function! vcs#impl#git#GetInfo() " {{{
  " better, but will error if the git repo has no commits
  "let info = vcs#impl#git#Git('rev-parse --abbrev-ref HEAD')
  let branch = vcs#impl#git#Git('branch')
  if branch == '0'
    return ''
  endif
  "let branch = substitute(branch, '\_s$', '', '')
  let branch = substitute(branch, '.*\*\s*\(.\{-}\)\(\n.*\|$\)', '\1', 'g')
  if branch == ''
    let branch = 'master'
  endif
  return 'git:' . branch
endfunction " }}}

function! vcs#impl#git#GetEditorFile() " {{{
  let line = getline('.')
  if line =~ '^#\s*modified:.*'
    let file = substitute(line, '^#\s*modified:\s\+\(.*\)\s*', '\1', '')
    if search('#\s\+Changed but not updated:', 'nw') > line('.')
      let result = vcs#impl#git#Git('diff --full-index --cached "' . file . '"')
      let lines = split(result, "\n")[:5]
      call filter(lines, 'v:val =~ "^index \\w\\+\\.\\.\\w\\+"')
      if len(lines)
        let index = substitute(lines[0], 'index \w\+\.\.\(\w\+\)\s.*', '\1', '')

        " kind of hacky but so far only git has a staging area, so return a
        " filename indicating the index blob version of the file which will
        " trigger an autocmd above that will populate the contents.
        let path = fnamemodify(file, ':h')
        let path .= path != '' ? '/' : ''
        return path . 'index_blob_' . index . '_' . fnamemodify(file, ':t')
      endif
    endif
    return file
  elseif line =~ '^#\s*new file:.*'
    return substitute(line, '^#\s*new file:\s\+\(.*\)\s*', '\1', '')
  endif
  return ''
endfunction " }}}

function! vcs#impl#git#GetModifiedFiles() " {{{
  let root = vcs#impl#git#GetRoot()
  let status = vcs#impl#git#Git('diff --name-status HEAD')
  let files = []
  for file in split(status, "\n")
    if file !~ '^[AM]\s\+'
      continue
    endif
    let file = substitute(file, '^[AM]\s\+', '', '')
    call add(files, root . '/' . file)
  endfor

  let untracked = vcs#impl#git#Git('ls-files --others --exclude-standard')
  let files += map(split(untracked, "\n"), 'root . "/" . v:val')

  return files
endfunction " }}}

function! vcs#impl#git#Info(path) " {{{
  let result = vcs#impl#git#Git('log -1 "' . a:path . '"')
  if type(result) == 0
    return
  endif
  call vcs#util#Echo(result)
endfunction " }}}

function! vcs#impl#git#Log(args, ...) " {{{
  " Optional args:
  "   exec: non-0 to run the command with exec

  let logcmd = 'log --pretty=tformat:"%h|%cn|%cr|%d|%s|"'
  if g:VcsLogMaxEntries > 0
    let logcmd .= ' -' . g:VcsLogMaxEntries
  endif
  if a:args != ''
    let logcmd .= ' ' . a:args
  endif

  let exec = len(a:000) > 0 ? a:000[0] : 0
  if exec
    let logcmd = escape(logcmd, '%')
  endif
  let result = vcs#impl#git#Git(logcmd, exec)
  if type(result) == 0
    return
  endif
  let log = []
  for line in split(result, '\n')
    let values = split(line, '|')
    let refs = split(substitute(values[3], '^\s*(\|)\s*$', '', 'g'), ',\s*')
    call add(log, {
        \ 'revision': values[0],
        \ 'author': values[1],
        \ 'age': values[2],
        \ 'refs': refs,
        \ 'comment': values[4],
     \ })
  endfor
  let root_dir = exists('b:vcs_props') ?
    \ b:vcs_props.root_dir : vcs#impl#git#GetRoot()
  return {'log': log, 'props': {'root_dir': root_dir}}
endfunction " }}}

function! vcs#impl#git#LogGrep(pattern, args, type) " {{{
  let args = ''
  if a:type == 'message'
    let args .= '-E "--grep=' . a:pattern . '"'
  elseif a:type == 'files'
    let args .= '--pickaxe-regex "-S' . a:pattern . '"'
  endif
  if a:args != ''
    let args .= ' ' . a:args
  endif

  return vcs#impl#git#Log(args, 1)
endfunction " }}}

function! vcs#impl#git#LogDetail(revision) " {{{
  let logcmd = 'log -1 --pretty=tformat:"%h|%cn|%cr|%ci|%d|%s|%s%n%n%b|" '
  let result = vcs#impl#git#Git(logcmd . a:revision)
  if type(result) == 0
    return
  endif
  let values = split(result, '|')
  let refs = split(substitute(values[4], '^\s*(\|)\s*$', '', 'g'), ',\s*')
  return {
      \ 'revision': values[0],
      \ 'author': values[1],
      \ 'age': values[2],
      \ 'date': values[3],
      \ 'refs': refs,
      \ 'comment': values[5],
      \ 'description': values[6],
   \ }
endfunction " }}}

function! vcs#impl#git#LogFiles(revision) " {{{
  let logcmd = 'log -1 --name-status --pretty=tformat:"" '
  let result = vcs#impl#git#Git(logcmd . a:revision)
  if type(result) == 0
    return
  endif
  let results = filter(split(result, '\n'), 'v:val !~ "^$"')
  let files = []
  for result in results
    if result =~ '^R'
      let [status, old, new] = split(result, '\t')
      call add(files, {'status': status[0], 'old': old, 'new': new})
    else
      let [status, file] = split(result, '\t')
      call add(files, {'status': status, 'file': file})
    endif
  endfor
  return files
endfunction " }}}

function! vcs#impl#git#ViewFileRevision(path, revision) " {{{
  let path = a:path

  " kind of a hack to support diffs against git's staging (index) area.
  if path =~ '\<index_blob_[a-z0-9]\{40}_'
    let path = substitute(path, '\<index_blob_[a-z0-9]\{40}_', '', '')
  endif

  let result = vcs#impl#git#Git('show "' . a:revision . ':' . path . '"')
  return split(result, '\n')
endfunction " }}}

function! vcs#impl#git#Git(args, ...) " {{{
  " Optional args:
  "   exec: non-0 to run the command with exec
  let exec = len(a:000) > 0 && a:000[0]
  let result = vcs#util#Vcs('git', '--no-pager ' . a:args, exec)

  " handle errors not caught by Vcs
  if type(result) == 1 && result =~ '^fatal:'
    call vcs#util#EchoError(
      \ "Error executing command: git --no-pager " . a:args . "\n" . result)
    throw 'vcs error'
  endif

  return result
endfunction " }}}

function! s:ReadIndex() " {{{
  " Used to read a file with the name index_blob_<index hash>_<filename>, for
  " use by the git editor diff support.
  setlocal noreadonly modifiable
  if !filereadable(expand('%'))
    let path = vcs#util#GetRelativePath()
    let path = substitute(path, '^/', '', '')
    let root = vcs#impl#git#GetRoot()
    exec 'lcd ' . escape(root, ' ')
    let index = substitute(path, '.*\<index_blob_\([a-z0-9]\{40}\)_.*', '\1', '')
    let path = substitute(path, '\<index_blob_[a-z0-9]\{40}_', '', '')
    let result = vcs#impl#git#Git('show ' . index)
    call append(1, split(result, "\n"))
  else
    read %
  endif
  1,1delete _
  setlocal readonly nomodifiable
endfunction " }}}

" vim:ft=vim:fdm=marker
