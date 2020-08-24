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

if !exists('g:vcs_util_loaded')
  let g:vcs_util_loaded = 1
else
  finish
endif

" Script Variables {{{
  let s:types = {'git': '.git', 'hg': '.hg'}

  let s:temp_dir = expand('$TMP')
  if s:temp_dir == '$TMP'
    let s:temp_dir = expand('$TEMP')
  endif
  if s:temp_dir == '$TEMP' && has('unix')
    let s:temp_dir = '/tmp'
  endif
  let s:temp_dir = substitute(s:temp_dir, '\', '/', 'g')
" }}}

function! vcs#util#GetVcsType() " {{{
  let path = fnamemodify(vcs#util#GetCurrentPath(), ':h')
  let result_dir = ''
  let result_vcs = ''
  for [type, dir] in items(s:types)
    let vcsdir = finddir(dir, path . ';')
    if vcsdir != ''
      let vcsdir = fnamemodify(vcsdir, ':p')
      if result_dir == '' || len(vcsdir) > len(result_dir)
        let result_dir = vcsdir
        let result_vcs = type
      endif
    endif
  endfor

  if result_dir != ''
    exec 'runtime autoload/vcs/impl/' . result_vcs . '.vim'
  endif
  return result_vcs
endfunction " }}}

function! vcs#util#GetVcsFunction(func_name) " {{{
  " Gets a reference to the proper vcs function.
  " Ex. let GetRevision = vcs#util#GetVcsFunction('GetRevision')
  let type = vcs#util#GetVcsType()
  if type == ''
    return
  endif

  try
    return function('vcs#impl#' . type . '#' . a:func_name)
  catch /E700:.*/
    call vcs#util#EchoError('This function is not supported by "' . type . '".')
    return
  endtry
endfunction " }}}

function! vcs#util#GetPreviousRevision(path, ...) " {{{
  " Gets the previous revision of the supplied path.
  " Optional args:
  "   revision

  let cwd = vcs#util#LcdRoot()
  try
    let GetPreviousRevision = vcs#util#GetVcsFunction('GetPreviousRevision')
    if type(GetPreviousRevision) != 2
      return
    endif
    if len(a:000) > 0
      let revision = GetPreviousRevision(a:path, a:000[0])
    else
      let revision = GetPreviousRevision(a:path)
    endif
  finally
    exec 'lcd ' . cwd
  endtry

  return revision
endfunction " }}}

function! vcs#util#GetRevision(path) " {{{
  let cwd = vcs#util#LcdRoot()
  try
    let GetRevision = vcs#util#GetVcsFunction('GetRevision')
    if type(GetRevision) != 2
      return
    endif
    let revision = GetRevision(a:path)
  finally
    exec 'lcd ' . cwd
  endtry
  return revision
endfunction " }}}

function! vcs#util#GetRevisions() " {{{
  " Gets a list of tags and branches.
  let revisions = []

  let cwd = vcs#util#LcdRoot()
  try
    let GetRevisions = vcs#util#GetVcsFunction('GetRevisions')
    if type(GetRevisions) == 2
      let revisions = GetRevisions()
    endif
  finally
    exec 'lcd ' . cwd
  endtry

  return revisions
endfunction " }}}

function! vcs#util#GetModifiedFiles() " {{{
  " Gets a list of modified files, including untracked files that are not
  " ignored.
  let files = []

  let cwd = vcs#util#LcdRoot()
  try
    let GetModifiedFiles = vcs#util#GetVcsFunction('GetModifiedFiles')
    if type(GetModifiedFiles) == 2
      let files = GetModifiedFiles()
    endif
  finally
    exec 'lcd ' . cwd
  endtry

  return files
endfunction " }}}

function! vcs#util#GetCurrentPath(...) " {{{
  " Get the path of the current or supplied file, accounting for symlinks.
  let path = len(a:000) > 0 && a:000[0] != '' ? a:000[0] : expand('%:p')
  return resolve(path)
endfunction " }}}

function! vcs#util#GetRelativePath(...) " {{{
  " Converts the current or supplied absolute path into a repos relative path.
  let path = vcs#util#GetCurrentPath(len(a:000) > 0 ? a:000[0] : '')
  let root = vcs#util#GetRoot(path)
  let path = substitute(path, '\', '/', 'g')
  let path = substitute(path, '^' . root, '', '')
  let path = substitute(path, '^/', '', '')
  return path
endfunction " }}}

function! vcs#util#GetRoot(...) " {{{
  " Gets the absolute path to the repository root on the local file system.
  if exists('b:vcs_props') && has_key(b:vcs_props, 'root_dir')
    return b:vcs_props.root_dir
  endif

  let root = ''

  let cwd = getcwd()
  let path = vcs#util#GetCurrentPath(len(a:000) > 0 ? a:000[0] : '')
  if !isdirectory(path)
    let path = fnamemodify(path, ':h')
  endif

  exec 'lcd ' . escape(path, ' ')
  try
    let GetRoot = vcs#util#GetVcsFunction('GetRoot')
    if type(GetRoot) == 2
      let root = GetRoot()
    endif
  finally
    exec 'lcd ' . escape(cwd, ' ')
  endtry

  return root
endfunction " }}}

function! vcs#util#GetInfo(dir) " {{{
  " Gets some displayable info for the specified vcs directory (branch info,
  " etc.)
  let info = ''

  let cwd = getcwd()
  let dir = a:dir == '' ? fnamemodify(vcs#util#GetCurrentPath(), ':h') : a:dir
  exec 'lcd ' . escape(dir, ' ')
  try
    let GetInfo = vcs#util#GetVcsFunction('GetInfo')
    if type(GetInfo) == 2
      let info = GetInfo()
    endif
  catch /E117/
    " function not found
  finally
    exec 'lcd ' . escape(cwd, ' ')
  endtry

  return info
endfunction " }}}

function! vcs#util#GetSettings() " {{{
  let vcs_root = vcs#util#GetRoot()
  if vcs_root =~ '/$'
    let vcs_root = vcs_root[:-2]
  endif
  for [key, settings] in items(g:VcsRepositorySettings)
    let key = expand(substitute(key, '\', '/', 'g'))
    if key =~ '^' . vcs_root . '\>/\?$'
      return settings
    endif
  endfor

  " try to detect settings based on the origin
  let GetOrigin = vcs#util#GetVcsFunction('GetOrigin')
  if type(GetOrigin) == 2
    let origin = GetOrigin()
    if origin != ''
      let host = substitute(origin, '.\{-}\(\w\+\)\.\(com\|net\|org\).*', '\1', '')
      let GetSettings = vcs#web#GetVcsWebFunction(host, 'GetSettings')
      if type(GetSettings) == 2
        try
          let settings = GetSettings(origin)
          let g:VcsRepositorySettings[vcs_root] = settings
          return settings
        catch /E117/
          " function not found
        endtry
      endif
    endif
  endif

  return {}
endfunction " }}}

function! vcs#util#LcdRoot(...) " {{{
  " lcd to the vcs root and return the previous working directory.
  let cwd = getcwd()
  let path = vcs#util#GetCurrentPath(len(a:000) > 0 ? a:000[0] : '')
  let root = vcs#util#GetRoot(path)
  exec 'lcd ' . escape(root, ' ')
  return escape(cwd, ' ')
endfunction " }}}

function! vcs#util#Vcs(cmd, args, ...) " {{{
  " Executes the supplied vcs command with the supplied args.
  " Optional args:
  "   exec: non-0 to run the command using exec

  if !executable(a:cmd)
    call vcs#util#EchoError(a:cmd . ' executable not found in your path.')
    return
  endif

  let cmd = a:cmd
  let args = a:args
  let exec = len(a:000) > 0 && a:000[0]
  if exec
    let cmd = '!' . cmd
  endif
  let [error, result] = vcs#util#System(cmd . ' ' . args, exec, 1)
  if error
    call vcs#util#EchoError(
      \ "Error executing command: " . a:cmd . " " . a:args . "\n" . result)
    throw 'vcs error'
  endif

  return result
endfunction " }}}

function! vcs#util#Echo(message) " {{{
  call s:Echo(a:message, 'Statement')
endfunction " }}}

function! vcs#util#EchoWarning(message) " {{{
  call s:Echo(a:message, 'WarningMsg')
endfunction " }}}

function! vcs#util#EchoError(message) " {{{
  call s:Echo(a:message, 'Error')
endfunction " }}}

function! s:Echo(message, highlight) " {{{
  " only echo if the result is not 0, which is most likely the result of an
  " error.
  if a:message != "0"
    exec "echohl " . a:highlight
    redraw
    for line in split(a:message, '\n')
      echom line
    endfor
    echohl None
  endif
endfunction " }}}

function! vcs#util#WideMessage(command, message) " {{{
  " Executes the supplied echo command and forces vim to display as much as
  " possible without the "Press Enter" prompt.
  " Thanks to vimtip #1289

  let saved_ruler = &ruler
  let saved_showcmd = &showcmd

  let message = substitute(a:message, '^\s\+', '', '')

  set noruler noshowcmd
  redraw
  if len(message) > &columns
    let remove = len(message) - &columns
    let start = (len(message) / 2) - (remove / 2) - 4
    let end = start + remove + 4
    let message = substitute(message, '\%' . start . 'c.*\%' . end . 'c', '...', '')
  endif
  exec a:command . ' "' . escape(message, '"\') . '"'

  let &ruler = saved_ruler
  let &showcmd = saved_showcmd
endfunction " }}}

function! vcs#util#PromptConfirm(prompt) " {{{
  " Creates a yes/no prompt for the user using the supplied prompt string.
  " Returns -1 if the user canceled, otherwise 1 for yes, and 0 for no.

  echohl Statement
  try
    " clear any previous messages
    redraw
    echo a:prompt . "\n"
    let response = input("(y/n): ")
    while response != '' && response !~ '^\c\s*\(y\(es\)\?\|no\?\|\)\s*$'
      let response = input("You must choose either y or n. (Ctrl-C to cancel): ")
    endwhile
  finally
    echohl None
  endtry

  if response == ''
    return -1
  endif

  return response =~ '\c\s*\(y\(es\)\?\)\s*'
endfunction " }}}

function! vcs#util#PromptList(prompt, list) " {{{
  " Creates a prompt for the user using the supplied prompt string and list of
  " items to choose from.  Returns -1 if the list is empty or if the user
  " canceled, and 0 if the list contains only one item.

  " no elements, no prompt
  if empty(a:list)
    return -1
  endif

  " only one elment, no need to choose.
  if len(a:list) == 1
    return 0
  endif

  let prompt = ""
  let index = 0
  for item in a:list
    let prompt = prompt . index . ") " . item . "\n"
    let index = index + 1
  endfor

  echohl Statement
  try
    " clear any previous messages
    redraw
    " echoing the list prompt vs. using it in the input() avoids apparent vim
    " bug that causes "Internal error: get_tv_string_buf()".
    echo prompt . "\n"
    let response = input(a:prompt . ": ")
    while response !~ '\(^$\|^[0-9]\+$\)' ||
        \ response < 0 ||
        \ response > (len(a:list) - 1)
      let response = input("You must choose a value between " .
        \ 0 . " and " . (len(a:list) - 1) . ". (Ctrl-C to cancel): ")
    endwhile
  finally
    echohl None
  endtry

  if response == ''
    return -1
  endif

  return response
endfunction " }}}

function! vcs#util#GoToBufferWindow(buf) " {{{
  " Focuses the window containing the supplied buffer name or buffer number.
  " Returns 1 if the window was found, 0 otherwise.
  if type(a:buf) == 0
    let winnr = bufwinnr(a:buf)
  else
    let name = vcs#util#EscapeBufferName(a:buf)
    let winnr = bufwinnr(bufnr('^' . name . '$'))
  endif
  if winnr != -1
    exec winnr . 'winc w'
    return 1
  endif
  return 0
endfunction " }}}

function! vcs#util#GoToBufferWindowOrOpen(name, cmd) " {{{
  " Gives focus to the window containing the buffer for the supplied file, or
  " if none, opens the file using the supplied command.
  let name = vcs#util#EscapeBufferName(a:name)
  let winnr = bufwinnr(bufnr('^' . name))
  if winnr != -1
    exec winnr . 'winc w'
  else
    let cmd = a:cmd
    " if splitting and the buffer is a unamed empty buffer, then switch to an
    " edit.
    if cmd == 'split' && expand('%') == '' &&
     \ !&modified && line('$') == 1 && getline(1) == ''
      let cmd = 'edit'
    endif
    silent exec 'keepalt ' . cmd . ' ' . escape(a:name, ' ')
  endif
endfunction " }}}

function! vcs#util#GoToBufferWindowRegister(buf) " {{{
  " Registers the autocmd for returning the user to the supplied buffer when
  " the current buffer is closed.
  exec 'autocmd BufWinLeave <buffer> ' .
    \ 'call vcs#util#GoToBufferWindow("' . escape(a:buf, '\') . '") | ' .
    \ 'doautocmd BufEnter'
endfunction " }}}

function! vcs#util#EscapeBufferName(name) " {{{
  " Escapes the supplied buffer name so that it can be safely used by buf*
  " functions.
  let name = a:name
  " escaping the space in cygwin could lead to the dos path error message that
  " cygwin throws when a dos path is referenced.
  if !has('win32unix')
    let name = escape(a:name, ' ')
  endif
  return substitute(name, '\(.\{-}\)\[\(.\{-}\)\]\(.\{-}\)', '\1[[]\2[]]\3', 'g')
endfunction " }}}

function! vcs#util#ParseArgs(args) " {{{
  " Parses the supplied argument line into a list of args, handling quoted
  " strings, escaped spaces, etc.
  let args = []
  let arg = ''
  let quote = ''
  let escape = 0
  let index = 0
  while index < len(a:args)
    let char = a:args[index]
    let index += 1
    if char == ' ' && quote == '' && !escape
      if arg != ''
        call add(args, arg)
        let arg = ''
      endif
    elseif char == '\'
      if escape
        let arg .= char
      endif
      let escape = !escape
    elseif char == '"' || char == "'"
      if !escape
        if quote != '' && char == quote
          let quote = ''
        elseif quote == ''
          let quote = char
        else
          let arg .= char
        endif
      else
        let arg .= char
        let escape = 0
      endif
    else
      if escape && char != ' '
        let arg .= '\'
      endif
      let arg .= char
      let escape = 0
    endif
  endwhile

  if arg != ''
    call add(args, arg)
  endif

  return args
endfunction " }}}

function! vcs#util#GetDefinedSigns() " {{{
  redir => list
  silent exec 'sign list'
  redir END

  let names = []
  for name in split(list, '\n')
    let name = substitute(name, 'sign\s\(.\{-}\)\s.*', '\1', '')
    call add(names, name)
  endfor
  return names
endfunction " }}}

function! vcs#util#GetExistingSigns(...) " {{{
  " Gets a list of existing signs for the current buffer.
  " The list consists of dictionaries with the following keys:
  "   id:   The sign id.
  "   line: The line number.
  "   name: The sign name (erorr, warning, etc.)
  "
  " Optionally a sign name may be supplied to only retrieve signs of that
  " name.

  let bufnr = bufnr('%')

  redir => signs
  silent exec 'sign place buffer=' . bufnr
  redir END

  let existing = []
  for line in split(signs, '\n')
    if line =~ '.\{-}=.\{-}=' " only two equals to account for swedish output
      call add(existing, s:ParseSign(line))
    endif
  endfor

  if len(a:000) > 0
    call filter(existing, "v:val['name'] == a:000[0]")
  endif

  return existing
endfunction " }}}

function! vcs#util#DefineSign(name, text) " {{{
  exec "sign define " . a:name . " text=" . a:text . " texthl=Statement"
endfunction " }}}

function! vcs#util#UndefineSign(name) " {{{
  exec "sign undefine " . a:name
endfunction " }}}

function! vcs#util#PlaceSign(name, line) " {{{
  if a:line > 0
    let lastline = line('$')
    let line = a:line <= lastline ? a:line : lastline
    exec "sign place " . line . " line=" . line . " name=" . a:name .
      \ " buffer=" . bufnr('%')
  endif
endfunction " }}}

function! vcs#util#UnplaceSign(id) " {{{
  exec 'sign unplace ' . a:id . ' buffer=' . bufnr('%')
endfunction " }}}

function! s:ParseSign(raw) " {{{
  let attrs = split(a:raw)

  exec 'let line = ' . split(attrs[0], '=')[1]

  let id = split(attrs[1], '=')[1]
  " hack for the italian localization
  if id =~ ',$'
    let id = id[:-2]
  endif

  " hack for the swedish localization
  if attrs[2] =~ '^namn'
    let name = substitute(attrs[2], 'namn', '', '')
  else
    let name = split(attrs[2], '=')[1]
  endif

  return {'id': id, 'line': line, 'name': name}
endfunction " }}}

function! vcs#util#System(cmd, ...) " {{{
  " Executes system() accounting for possibly disruptive vim options.
  " Optional args:
  "   exec: non-0 to run the command using exec
  "   exec_results: non-0 to return the output from the exec command
  let saveshell = &shell
  let saveshellcmdflag = &shellcmdflag
  let saveshellpipe = &shellpipe
  let saveshellquote = &shellquote
  let saveshellredir = &shellredir
  let saveshellslash = &shellslash
  let saveshelltemp = &shelltemp
  let saveshellxquote = &shellxquote

  if has('win32') || has('win64')
    set shell=cmd.exe shellcmdflag=/c
    set shellpipe=>%s\ 2>&1 shellredir=>%s\ 2>&1
    set shellquote= shellxquote=
    set shelltemp noshellslash
  else
    if executable('/bin/bash')
      set shell=/bin/bash
    else
      set shell=/bin/sh
    endif
    set shellcmdflag=-c
    set shellpipe=2>&1\|\ tee shellredir=>%s\ 2>&1
    set shellquote= shellxquote=
    set shelltemp noshellslash
  endif

  " use exec
  if len(a:000) > 0 && a:000[0]
    let cmd = a:cmd
    let exec_output = len(a:000) > 1 ? a:000[1] : 0
    if exec_output
      let outfile = s:temp_dir . '/vcs_exec_output.txt'
      if has('win32') || has('win64') || has('win32unix')
        let cmd = substitute(cmd, '^"\(.*\)"$', '\1', '')
        let cmd = substitute(cmd, '^!', '', '')
        " dos blows
        let cmd = substitute(cmd, '|', '^^^|', 'g')
        if executable('tee')
          let teefile = has('win32unix') ? s:Cygpath(outfile) : outfile
          let cmd = '!cmd /c "' . cmd . ' 2>&1 | tee "' . teefile . '" "'
        else
          let cmd = '!cmd /c "' . cmd . ' >"' . outfile . '" 2>&1 "'
        endif
      else
        let cmd .= ' 2>&1| tee "' . outfile . '"'
      endif
    endif

    exec cmd

    let result = ''
    if exec_output
      let result = join(readfile(outfile), "\n")
      call delete(outfile)
    endif

  " use system
  else
    let result = system(a:cmd)
  endif

  let &shell = saveshell
  let &shellcmdflag = saveshellcmdflag
  let &shellquote = saveshellquote
  let &shellslash = saveshellslash
  let &shelltemp = saveshelltemp
  let &shellxquote = saveshellxquote
  let &shellpipe = saveshellpipe
  let &shellredir = saveshellredir

  return [v:shell_error, result]
endfunction " }}}

function! s:Cygpath(path) " {{{
  if executable('cygpath')
    let path = substitute(a:path, '\', '/', 'g')
    let [error, path] = vcs#util#System('cygpath "' . path . '"')
    let path = substitute(path, '\n$', '', '')
    return path
  endif
  return a:path
endfunction " }}}

function! vcs#util#CommandCompleteRevision(argLead, cmdLine, cursorPos) " {{{
  let cmdLine = strpart(a:cmdLine, 0, a:cursorPos)
  let args = split(cmdLine, '[^\\]\s\zs')
  call map(args, 'substitute(v:val, "\\([^\\\\]\\)\\s\\+$", "\\1", "")')
  let argLead = cmdLine =~ '\s$' ? '' : args[len(args) - 1]

  let revisions = vcs#util#GetRevisions()
  call filter(revisions, 'v:val =~ "^' . argLead . '"')
  return revisions
endfunction " }}}

" vim:ft=vim:fdm=marker
