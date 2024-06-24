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

runtime autoload/vcs/util.vim

" Global Variables {{{
  if !exists('g:VcsLogMaxEntries')
    let g:VcsLogMaxEntries = 0
  endif

  if !exists('g:VcsDiffOrientation')
    let g:VcsDiffOrientation = 'vertical'
  endif
" }}}

function! vcs#command#Annotate(...) " {{{
  " Optional args:
  "   revision

  if exists('b:vcs_annotations')
    call s:AnnotateOff()
    return
  endif

  let path = exists('b:vcs_props') ? b:vcs_props.path :
    \ vcs#util#GetRelativePath()
  let revision = len(a:000) > 0 ? a:000[0] : ''

  " let the vcs annotate the current working version so that the results line
  " up with the contents (assuming the underlying vcs supports it).
  "if revision == ''
  "  let revision = vcs#util#GetRevision()
  "endif

  let cwd = vcs#util#LcdRoot()
  try
    let Annotate = vcs#util#GetVcsFunction('GetAnnotations')
    if type(Annotate) != 2
      call vcs#util#EchoError(
        \ 'Current file is not under version control.')
      return
    endif
    let annotations = Annotate(path, revision)
  finally
    exec 'lcd ' . cwd
  endtry

  call s:ApplyAnnotations(annotations)
endfunction " }}}

function! vcs#command#Diff(revision, ...) " {{{
  " Diffs the current file against the current or supplied revision.
  " Optional args:
  "   bang: when not empty, open the diff using the opposite of the configured
  "         default.

  let path = expand('%:p')
  let relpath = vcs#util#GetRelativePath()
  let revision = a:revision
  if revision == ''
    let revision = vcs#util#GetRevision(relpath)
    if revision == ''
      call vcs#util#Echo('Unable to determine file revision.')
      return
    endif
  elseif revision == 'prev'
    let revision = vcs#util#GetPreviousRevision(relpath)
  endif

  let filename = expand('%:p')
  let buf1 = bufnr('%')

  let orien = g:VcsDiffOrientation == 'horizontal' ? '' : 'vertical'
  if a:0 && a:1 != ''
    let orien = orien == '' ? 'vertical' : ''
  endif

  call vcs#command#ViewFileRevision(path, revision, 'bel ' . orien . ' split')
  diffthis

  let b:filename = filename
  let b:vcs_diff_temp = 1
  augroup vcs_diff
    autocmd! BufWinLeave <buffer>
    call vcs#util#GoToBufferWindowRegister(b:filename)
    autocmd BufWinLeave <buffer> diffoff
  augroup END

  call vcs#util#GoToBufferWindow(buf1)
  diffthis
endfunction " }}}

function! vcs#command#Info() " {{{
  " Retrieves and echos info on the current file.
  let path = vcs#util#GetRelativePath()
  let cwd = vcs#util#LcdRoot()
  try
    let Info = vcs#util#GetVcsFunction('Info')
    if type(Info) == 2
      call Info(path)
    endif
  finally
    exec 'lcd ' . cwd
  endtry
endfunction " }}}

function! vcs#command#Log(args) " {{{
  " Opens a buffer with the results of running a log for the supplied
  " arguments.
  let cwd = vcs#util#LcdRoot()
  let args = a:args
  let path = a:args == '' ? vcs#util#GetRelativePath() : ''
  try
    let Log = vcs#util#GetVcsFunction('Log')
    if type(Log) != 2
      return
    endif

    " handle user supplied % arg
    let arglist = vcs#util#ParseArgs(args)
    let percent_index = index(arglist, '%')
    if percent_index != -1
      call remove(arglist, percent_index)
      let path = vcs#util#GetRelativePath()
      let args = '"' . join(arglist, '" "') . '" '
    endif

    if path != ''
      let args .= '"' . path . '"'
    endif
    let info = Log(args)
  finally
    exec 'lcd ' . cwd
  endtry

  " if annotations are on, jump to the revision for the current line
  let jumpto = ''
  if exists('b:vcs_annotations') && len(b:vcs_annotations) >= line('.')
    let jumpto = split(b:vcs_annotations[line('.') - 1])[0]
  endif

  let content = []
  if path != ''
    let info.props.path = path
    call add(content, path)
    call add(content, '')
  endif
  for entry in info.log
    call add(content, s:LogLine(entry))
  endfor

  if g:VcsLogMaxEntries > 0 && len(info.log) == g:VcsLogMaxEntries
    call add(content, '------------------------------------------')
    call add(content, 'Note: entries limited to ' . g:VcsLogMaxEntries . '.')
    call add(content, '      let g:VcsLogMaxEntries = ' . g:VcsLogMaxEntries)
  endif

  call s:TempWindow(info.props, content)
  call s:LogSyntax()
  call s:LogMappings()

  " continuation of annotation support
  if jumpto != ''
    " in the case of git, the annotate hash is longer than the log hash, so
    " perform a little extra work to line them up.
    let line = search('^[+-] \w\+', 'n')
    if line != -1
      let hash = substitute(getline(line), '^[+-] \(\w\+\) .*', '\1', '')
      let jumpto = jumpto[:len(hash)-1]
    endif

    call search('^[+-] ' . jumpto)
    normal! z
  endif
endfunction " }}}

function! vcs#command#LogGrep(args, type) " {{{
  if a:args == ''
    call vcs#util#EchoError('Pattern required.')
    return
  endif

  let cwd = vcs#util#LcdRoot()
  try
    let LogGrep = vcs#util#GetVcsFunction('LogGrep')
    if type(LogGrep) != 2
      return
    endif

    let arglist = vcs#util#ParseArgs(a:args)
    let pattern = arglist[0]
    " translate a few vim regex atoms to pcre
    let pattern = substitute(pattern, '\\[<>]', '\\b', 'g')
    let pattern = substitute(pattern, '\\{-}', '*?', 'g')
    " vim sometimes adds a leading 'very nomagic' when using normal *
    let pattern = substitute(pattern, '^\\V', '', '')
    let arglist = arglist[1:]

    " handle user supplied % arg
    let percent_index = index(arglist, '%')
    if percent_index != -1
      let arglist[percent_index] = vcs#util#GetRelativePath()
    endif
    let args = len(arglist) ? '"' . join(arglist, '" "') . '"' : ''
    let info = LogGrep(pattern, args, a:type)
  finally
    exec 'lcd ' . cwd
  endtry

  let content = [
    \ 'pattern: ' . pattern .
    \ (len(arglist) ? ' args: ' . join(arglist, ', ') : '')
    \ , '']
  for entry in info.log
    call add(content, s:LogLine(entry))
  endfor

  call s:TempWindow(info.props, content)
  call s:LogSyntax()
  call s:LogMappings()
endfunction " }}}

function! vcs#command#ViewFileRevision(path, revision, open_cmd) " {{{
  " Open a read only view for the revision of the supplied version file.
  let path = vcs#util#GetRelativePath(a:path)
  let revision = a:revision
  if revision == ''
    let revision = vcs#util#GetRevision(path)
    if revision == ''
      call vcs#util#Echo('Unable to determine file revision.')
      return
    endif
  elseif revision == 'prev'
    let revision = vcs#util#GetPreviousRevision(path)
  endif

  let props = exists('b:vcs_props') ? b:vcs_props : s:GetProps()

  if exists('b:filename')
    let result = vcs#util#GoToBufferWindow(b:filename)
    if !result && exists('b:winnr')
      exec b:winnr . 'winc w'
    endif
  endif
  let vcs_file = 'vcs_' . revision . '_' . fnamemodify(path, ':t')

  let cwd = vcs#util#LcdRoot()
  let orig_buf = bufnr('%')
  try
    " load in content
    let ViewFileRevision = vcs#util#GetVcsFunction('ViewFileRevision')
    if type(ViewFileRevision) != 2
      return
    endif
    let lines = ViewFileRevision(path, revision)
  finally
    " switch back to the original cwd for both the original + new buffer.
    let cur_buf = bufnr('%')
    call vcs#util#GoToBufferWindow(orig_buf)
    exec 'lcd ' . cwd
    call vcs#util#GoToBufferWindow(cur_buf)
    exec 'lcd ' . cwd
  endtry

  let open_cmd = a:open_cmd != '' ? a:open_cmd : 'split'
  if has('win32') || has('win64')
    let vcs_file = substitute(vcs_file, ':', '_', 'g')
  endif
  call vcs#util#GoToBufferWindowOrOpen(vcs_file, open_cmd)
  call s:VcsContent(lines)

  let b:vcs_props = copy(props)
endfunction " }}}

function! vcs#command#ViewCommitPatch(revision) " {{{
  let cwd = vcs#util#LcdRoot()
  try
    " load in content
    let ViewCommitPatch = vcs#util#GetVcsFunction('ViewCommitPatch')
    if type(ViewCommitPatch) != 2
      return
    endif
    let lines = ViewCommitPatch(a:revision)
  finally
    exec 'lcd ' . cwd
  endtry

  let props = exists('b:vcs_props') ? b:vcs_props : s:GetProps()
  if exists('b:filename')
    let result = vcs#util#GoToBufferWindow(b:filename)
    if !result && exists('b:winnr')
      exec b:winnr . 'winc w'
    endif
  endif

  let vcs_file = 'vcs_' . a:revision
  call vcs#util#GoToBufferWindowOrOpen(vcs_file, 'split')

  call s:VcsContent(lines)
  setlocal ft=patch

  let b:vcs_props = props
endfunction " }}}

function! s:ApplyAnnotations(annotations) " {{{
  let existing = {}
  let existing_annotations = {}
  for exists in vcs#util#GetExistingSigns()
    if exists.name !~ '^\(vcs_annotate_\|placeholder\)'
      let existing[exists.line] = exists
    else
      let existing_annotations[exists.line] = exists
    endif
  endfor

  let defined = vcs#util#GetDefinedSigns()
  let index = 1
  let previous = ''
  for annotation in a:annotations
    if !has_key(existing, index)
      if annotation == 'uncommitted'
        let sign_name = 'vcs_annotate_uncommitted'
        let sign = '\ +'
      else
        let user = substitute(annotation, '^.\{-})\s\+\(.\{-}\)\s*$', '\1', '')
        let sign = user[:1]
        let name_parts = split(user)
        " if the user name appears to be in the form of First Last, then try using
        " using the first letter of each as initials
        if len(name_parts) > 1 && name_parts[0] =~ '^\w' && name_parts[1] =~ '^\w'
          let sign = name_parts[0][0] . name_parts[1][0]
        endif

        let sign_name = 'vcs_annotate_' . substitute(user[:5], ' ', '_', 'g')
        if annotation == previous
          let sign_name .= '_cont'
          let sign = '\ ▕'
        endif
      endif

      if index(defined, sign_name) == -1
        call vcs#util#DefineSign(sign_name, sign)
        call add(defined, sign_name)
      endif
      call vcs#util#PlaceSign(sign_name, index)
    endif
    let index += 1
    let previous = annotation
  endfor

  let b:vcs_annotations = a:annotations
  let b:vcs_props = s:GetProps()

  call s:AnnotateInfo()

  command! -buffer VcsAnnotateCat call s:AnnotateCat()
  command! -buffer VcsAnnotateDiff call s:AnnotateDiff()
  augroup vcs_annotate
    autocmd!
    autocmd CursorMoved <buffer> call <SID>AnnotateInfo()
    autocmd BufWritePost <buffer>
      \ if exists('b:vcs_annotations') |
      \   unlet b:vcs_annotations |
      \ endif |
      \ call vcs#command#Annotate() |
  augroup END
endfunction " }}}

function! s:AnnotateInfo() " {{{
  if mode() != 'n'
    return
  endif

  if exists('b:vcs_annotations') && len(b:vcs_annotations) >= line('.')
    let annotation = b:vcs_annotations[line('.') - 1]
    if annotation == 'uncommitted'
      let info = annotation
    else
      let GetInfo = vcs#util#GetVcsFunction('GetAnnotationInfo')
      let info = GetInfo(annotation)
    endif
    call vcs#util#WideMessage('echo', info)
  endif
endfunction " }}}

function! s:AnnotateOff() " {{{
  if exists('b:vcs_annotations')
    let defined = vcs#util#GetDefinedSigns()
    let previous = ''
    for annotation in b:vcs_annotations
      if annotation == 'uncommitted'
        let sign_name = 'vcs_annotate_uncommitted'
      else
        let user = substitute(annotation, '^.\{-})\s\+\(.\{-}\)\s*$', '\1', '')
        let sign_name = 'vcs_annotate_' . substitute(user[:5], ' ', '_', 'g')
      endif
      if annotation == previous
        let sign_name .= '_cont'
      endif
      if index(defined, sign_name) != -1
        let signs = vcs#util#GetExistingSigns(sign_name)
        for sign in signs
          call vcs#util#UnplaceSign(sign.id)
        endfor
        call vcs#util#UndefineSign(sign_name)
        call remove(defined, index(defined, sign_name))
      endif
      let previous = annotation
    endfor
    unlet b:vcs_annotations
    unlet b:vcs_props
  endif

  delcommand VcsAnnotateCat
  delcommand VcsAnnotateDiff
  augroup vcs_annotate
    autocmd!
  augroup END
endfunction " }}}

function! s:AnnotateCat() " {{{
  if exists('b:vcs_annotations') && len(b:vcs_annotations) >= line('.')
    let revision = split(b:vcs_annotations[line('.') - 1])[0]
    call vcs#command#ViewFileRevision(b:vcs_props.path, revision, '')
  endif
endfunction " }}}

function! s:AnnotateDiff() " {{{
  if exists('b:vcs_annotations') && len(b:vcs_annotations) >= line('.')
    let revision = split(b:vcs_annotations[line('.') - 1])[0]
    call vcs#command#Diff(revision)
  endif
endfunction " }}}

function! s:Action() " {{{
  try
    let line = getline('.')
    let link = substitute(
      \ getline('.'), '.*|\(.\{-}\%' . col('.') . 'c.\{-}\)|.*', '\1', '')

    if link == line && line =~ '^\s\+[+-] files\>.*$'
      call s:ToggleFiles()
      return
    endif

    if line =~ '^[+-] \w\+'
      call s:ToggleDetail()
      return
    endif

    if link == line
      return
    endif

    let settings = vcs#util#GetSettings()
    let ticket_id_patterns = get(settings, 'patterns', {})
    let ticket_id_pattern = join(keys(ticket_id_patterns), '\|')

    " link to commit patch
    if link == 'view patch'
      let revision = s:GetRevision()
      call vcs#command#ViewCommitPatch(revision)

    " link to view / annotate a file
    elseif link == 'view' || link == 'annotate'
      let file = s:GetFilePath()
      let revision = s:GetRevision()

      call vcs#command#ViewFileRevision(file, revision, '')
      if link == 'annotate'
        call vcs#command#Annotate(revision)
      endif

    " link to diff one version against previous
    elseif link =~ '^diff '
      let file = s:GetFilePath()
      let revision = s:GetRevision()
      let orien = g:VcsDiffOrientation == 'horizontal' ? '' : 'vertical'

      if link =~ 'previous'
        let previous = s:GetPreviousRevision()
        if previous != ''
          call vcs#command#ViewFileRevision(file, revision, '')
          let buf1 = bufnr('%')
          call vcs#command#ViewFileRevision(file, previous, 'bel ' . orien . ' split')
          diffthis
          call vcs#util#GoToBufferWindow(buf1)
          diffthis
        endif
      else
        let filename = b:filename
        call vcs#command#ViewFileRevision(file, revision, 'bel ' . orien . ' split')
        diffthis

        let b:filename = filename
        augroup vcs_diff
          autocmd! BufWinLeave <buffer>
          call vcs#util#GoToBufferWindowRegister(b:filename)
          autocmd BufWinLeave <buffer> diffoff
        augroup END

        call vcs#util#GoToBufferWindow(filename)
        diffthis
      endif

    " link to bug / feature report
    elseif link =~ '^' . ticket_id_pattern . '$'
      " we matched our combined pattern, now loop over our list of patterns to
      " find the exact pattern matched and the url it maps to
      let url = v:null
      for [pattern, url] in items(ticket_id_patterns)
        if link =~ '^' . pattern . '$'
          break
        endif
      endfor

      if type(url) == type(v:null)
        call vcs#util#EchoWarning(
          \ "Links to ticketing systems requires that you setup the \n" .
          \ "'patterns' for your repository in g:VcsRepositorySettings.")
        return
      endif

      let id = substitute(link, pattern, '\1', '')
      let url = substitute(url, '<id>', id, 'g')
      call vcs#web#OpenUrl(url)

    " added file
    elseif link == 'A'
      let file = substitute(line, '.*|A|\s*', '', '')
      let revision = s:GetRevision()
      call vcs#command#ViewFileRevision(file, revision, '')

    " modified or renamed file
    elseif link == 'M' || link == 'R'
      let revision = s:GetRevision()
      if link == 'M'
        let file = substitute(line, '.*|M|\s*', '', '')
        let old = file
        let previous = vcs#util#GetPreviousRevision(file, revision)
      else
        let file = substitute(line, '.*|R|.*->\s*', '', '')
        let old = substitute(line, '.*|R|\s*\(.*\)\s->.*', '\1', '')
        let previous = vcs#util#GetPreviousRevision(old)
      endif
      call vcs#command#ViewFileRevision(file, revision, '')
      let buf1 = bufnr('%')
      let orien = g:VcsDiffOrientation == 'horizontal' ? '' : 'vertical'
      call vcs#command#ViewFileRevision(old, previous, 'bel ' . orien . ' split')
      diffthis
      call vcs#util#GoToBufferWindow(buf1)
      diffthis

    " deleted file
    elseif link == 'D'
      let file = substitute(line, '.*|D|\s*', '', '')
      let revision = s:GetRevision()
      let previous = vcs#util#GetPreviousRevision(file, revision)
      call vcs#command#ViewFileRevision(file, previous, '')

    endif
  catch /vcs error/
    " the error message is printed by vcs#util#Vcs
  endtry
endfunction " }}}

function! s:LogLine(entry) " {{{
  let entry = a:entry
  let refs = ''
  if len(entry.refs)
    let refs = '(' . join(entry.refs, ', ') . ') '
  endif
  return printf('+ %s %s%s (%s) %s',
    \ entry.revision, refs, entry.author, entry.age, entry.comment)
endfunction " }}}

function! s:ToggleDetail() " {{{
  let line = getline('.')
  let lnum = line('.')
  let revision = s:GetRevision()
  let log = s:LogDetail(revision)

  let settings = vcs#util#GetSettings()
  let ticket_id_patterns = get(settings, 'patterns', {})
  if len(ticket_id_patterns) > 0
    let ticket_id_pattern = '\(' . join(keys(ticket_id_patterns), '\|') . '\)\>'
  else
    let ticket_id_pattern = ''
  endif

  setlocal modifiable noreadonly
  if line =~ '^+'
    let open = substitute(line, '+ \(.\{-})\).*', '- \1 ' . log.date, '')
    call setline(lnum, open)
    let lines = []
    if has_key(b:vcs_props, 'path')
      if lnum == line('$')
        call add(lines, "\t|view| |annotate| |diff working copy|")
      else
        call add(lines, "\t|view| |annotate| |diff working copy| |diff previous|")
      endif
    endif
    let desc = substitute(log.description, '\_s*$', '', '')
    if ticket_id_pattern != ''
      let desc = substitute(desc, '\('. ticket_id_pattern . '\)', '|\1|', 'g')
    endif
    let lines += map(split(desc, "\n"), '(v:val != "" ? "\t" : "") . v:val')
    call add(lines, '')
    call add(lines, "\t+ files |view patch|")
    call append(lnum, lines)
    retab
  else
    let pos = getpos('.')
    call setline(lnum, s:LogLine(log))
    let end = search('^[+-] \w\+', 'nW') - 1
    if end == -1
      let end = line('$')
    endif
    silent exec lnum + 1 . ',' . end . 'delete _'
    call setpos('.', pos)
  endif
  setlocal nomodifiable readonly
endfunction " }}}

function! s:ToggleFiles() " {{{
  let line = getline('.')
  let lnum = line('.')
  let revision = s:GetRevision()

  setlocal modifiable noreadonly
  if line =~ '^\s\++'
    let open = substitute(line, '+', '-', '')
    call setline(lnum, open)
    let files = s:LogFiles(revision)
    let lines = []
    for file in files
      if file.status == 'R'
        call add(lines, "\t\t|" . file.status . "| " . file.old . ' -> ' . file.new)
      else
        call add(lines, "\t\t|" . file.status . "| " . file.file)
      endif
    endfor
    call append(lnum, lines)
    retab
  else
    let pos = getpos('.')
    let close = substitute(line, '-', '+', '')
    call setline(lnum, close)
    let start = lnum + 1
    let end = search('^[+-] \w\+', 'cnW') - 1
    if end != lnum
      if end == -1
        let end = line('$')
      endif
      if end < start
        let end = start
      endif
      silent exec start . ',' . end . 'delete _'
      call setpos('.', pos)
    endif
  endif
  setlocal nomodifiable readonly
endfunction " }}}

function! s:GetProps() " {{{
  return {
      \ 'root_dir': vcs#util#GetRoot(),
      \ 'path': vcs#util#GetRelativePath(),
    \ }
endfunction " }}}

function! s:GetFilePath() " {{{
  return getline(1)
endfunction " }}}

function! s:GetRevision() " {{{
  let lnum = search('^[+-] \w\+', 'bcnW')
  return substitute(getline(lnum), '[+-] \(\w\+\) .*', '\1', '')
endfunction " }}}

function! s:GetPreviousRevision() " {{{
  let lnum = search('^[+-] \w\+', 'nW')
  if lnum == 0
    call vcs#util#EchoWarning('Could not find the previous revision number')
    return ''
  endif
  return substitute(getline(lnum), '[+-] \(\w\+\) .*', '\1', '')
endfunction " }}}

function! s:LogDetail(revision) " {{{
  let LogDetail = vcs#util#GetVcsFunction('LogDetail')
  if type(LogDetail) != 2
    return
  endif
  return LogDetail(a:revision)
endfunction " }}}

function! s:LogFiles(revision) " {{{
  let LogFiles = vcs#util#GetVcsFunction('LogFiles')
  if type(LogFiles) != 2
    return
  endif
  return LogFiles(a:revision)
endfunction " }}}

function! s:LogMappings() " {{{
  nnoremap <silent> <buffer> <cr> :call <SID>Action()<cr>
endfunction " }}}

function! s:LogSyntax() " {{{
  set ft=vcs_log
  hi link VcsRevision Identifier
  hi link VcsRefs Tag
  hi link VcsDate String
  hi link VcsLink Label
  hi link VcsFiles Comment
  syntax match VcsRevision /\(^[+-] \)\@<=\w\+/
  syntax match VcsRefs /\(^[+-] \w\+ \)\@<=(.\{-})/
  syntax match VcsDate /\(^[+-] \w\+ \((.\{-}) \)\?\w.\{-}\)\@<=(\d.\{-})/
  syntax match VcsLink /|\S.\{-}|/
  exec 'syntax match VcsFiles /\(^\s\+[+-] \)\@<=files\>/'
endfunction " }}}

function! s:TempWindow(props, lines) " {{{
  let winnr = winnr()
  let filename = expand('%:p')
  if expand('%') == '[vcs_log]' && exists('b:filename')
    let filename = b:filename
    let winnr = b:winnr
  endif

  let name = vcs#util#EscapeBufferName('[vcs_log]')
  if bufwinnr(name) == -1
    silent! noautocmd exec "keepalt botright 10sview " . escape('[vcs_log]', ' ')
    setlocal nowrap
    setlocal winfixheight
    setlocal noswapfile nobuflisted
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal modifiable noreadonly
    silent doautocmd WinEnter
  else
    exec bufwinnr(name) . "winc w"
    setlocal modifiable noreadonly
    silent 1,$delete _
    silent doautocmd WinEnter
  endif

  call append(1, a:lines)
  retab
  silent 1,1delete _

  setlocal nomodified nomodifiable readonly
  silent doautocmd BufEnter

  let b:filename = filename
  let b:winnr = winnr
  let b:vcs_props = a:props
  exec 'lcd ' . escape(a:props.root_dir, ' ')

  augroup vcs_temp_window
    autocmd! BufWinLeave <buffer>
    call vcs#util#GoToBufferWindowRegister(b:filename)
  augroup END
endfunction " }}}

function! s:VcsContent(lines) " {{{
  setlocal noreadonly
  setlocal modifiable
  silent 1,$delete _
  call append(1, a:lines)
  silent 1,1delete
  call cursor(1, 1)
  setlocal nomodified
  setlocal readonly
  setlocal nomodifiable
  setlocal noswapfile
  setlocal nobuflisted
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  doautocmd BufReadPost

  " work around a possible vim bug where setting this buffer as nomodifiable
  " above affects all unnamed buffers, despite using setlocal and the fact
  " that 'modifiable' is a local buffer only option.
  " Note: using 'set' vs 'setlocal' since 'setlocal' doesn't seem to work,
  " again despite the docs noting that 'modifiable' is a buffer local only
  " option.
  autocmd! BufUnload <buffer> set modifiable
endfunction " }}}

" vim:ft=vim:fdm=marker
