" Author:  Eric Van Dewoestine
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

" GetVcsType() {{{
function vcs#util#GetVcsType()
  let cwd = escape(getcwd(), ' ')
  let result_dir = ''
  let result_vcs = ''
  for [type, dir] in items(s:types)
    let vcsdir = finddir(dir, cwd . ';')
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

" GetVcsFunction(func_name) {{{
" Gets a reference to the proper vcs function.
" Ex. let GetRevision = vcs#util#GetVcsFunction('GetRevision')
function vcs#util#GetVcsFunction(func_name)
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

" GetPreviousRevision(path, [revision]) {{{
" Gets the previous revision of the supplied path.
function vcs#util#GetPreviousRevision(path, ...)
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

" GetRevision(path) {{{
" Gets the current revision of the current or supplied file.
function vcs#util#GetRevision(path)
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

" GetRevisions() {{{
" Gets a list of tags and branches.
function vcs#util#GetRevisions()
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

" GetModifiedFiles() {{{
" Gets a list of modified files, including untracked files that are not
" ignored.
function vcs#util#GetModifiedFiles()
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

" GetRelativePath(path) {{{
" Converts the supplied absolute path into a repos relative path.
function vcs#util#GetRelativePath(path)
  let root = vcs#util#GetRoot(a:path)
  let path = substitute(a:path, '\', '/', 'g')
  let path = substitute(path, '^' . root, '', '')
  let path = substitute(path, '^/', '', '')
  return path
endfunction " }}}

" GetRoot([path]) {{{
" Gets the absolute path to the repository root on the local file system.
function vcs#util#GetRoot(...)
  if exists('b:vcs_props') && has_key(b:vcs_props, 'root_dir')
    return b:vcs_props.root_dir
  endif

  let root = ''

  let cwd = getcwd()
  let path = len(a:000) > 0 && a:000[0] != '' ? a:000[0] : expand('%:p')
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

" GetInfo(dir) {{{
" Gets some displayable info for the specified vcs directory (branch info, etc.)
function vcs#util#GetInfo(dir)
  let info = ''

  let cwd = getcwd()
  let dir = a:dir == '' ? expand('%:p:h') : a:dir
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

" GetSettings() {{{
function vcs#util#GetSettings()
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
  return {}
endfunction " }}}

" LcdRoot([path]) {{{
" lcd to the vcs root and return the previous working directory.
function vcs#util#LcdRoot(...)
  let cwd = getcwd()
  let path = len(a:000) > 0 ? a:000[0] : expand('%:p')
  let root = vcs#util#GetRoot(path)
  exec 'lcd ' . escape(root, ' ')
  return escape(cwd, ' ')
endfunction " }}}

" Vcs(cmd, args [, exec]) {{{
" Executes the supplied vcs command with the supplied args.
function vcs#util#Vcs(cmd, args, ...)
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

" Echo(message) {{{
function! vcs#util#Echo(message)
  call s:Echo(a:message, 'Statement')
endfunction " }}}

" EchoWarning(message) {{{
function! vcs#util#EchoWarning(message)
  call s:Echo(a:message, 'WarningMsg')
endfunction " }}}

" EchoError(message) {{{
function! vcs#util#EchoError(message)
  call s:Echo(a:message, 'Error')
endfunction " }}}

" s:EchoLevel(message) {{{
function! s:Echo(message, highlight)
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

" WideMessage(command, message) {{{
" Executes the supplied echo command and forces vim to display as much as
" possible without the "Press Enter" prompt.
" Thanks to vimtip #1289
function! vcs#util#WideMessage(command, message)
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

" PromptConfirm(prompt) {{{
" Creates a yes/no prompt for the user using the supplied prompt string.
" Returns -1 if the user canceled, otherwise 1 for yes, and 0 for no.
function! vcs#util#PromptConfirm(prompt)
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

" PromptList(prompt, list) {{{
" Creates a prompt for the user using the supplied prompt string and list of
" items to choose from.  Returns -1 if the list is empty or if the user
" canceled, and 0 if the list contains only one item.
function! vcs#util#PromptList(prompt, list)
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

" GoToBufferWindow(buf) {{{
" Focuses the window containing the supplied buffer name or buffer number.
" Returns 1 if the window was found, 0 otherwise.
function! vcs#util#GoToBufferWindow(buf)
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

" GoToBufferWindowOrOpen(name, cmd) {{{
" Gives focus to the window containing the buffer for the supplied file, or if
" none, opens the file using the supplied command.
function! vcs#util#GoToBufferWindowOrOpen(name, cmd)
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
    silent exec cmd . ' ' . escape(a:name, ' ')
  endif
endfunction " }}}

" GoToBufferWindowRegister(buf) {{{
" Registers the autocmd for returning the user to the supplied buffer when the
" current buffer is closed.
function! vcs#util#GoToBufferWindowRegister(buf)
  exec 'autocmd BufWinLeave <buffer> ' .
    \ 'call vcs#util#GoToBufferWindow("' . escape(a:buf, '\') . '") | ' .
    \ 'doautocmd BufEnter'
endfunction " }}}

" EscapeBufferName(name) {{{
" Escapes the supplied buffer name so that it can be safely used by buf*
" functions.
function! vcs#util#EscapeBufferName(name)
  let name = a:name
  " escaping the space in cygwin could lead to the dos path error message that
  " cygwin throws when a dos path is referenced.
  if !has('win32unix')
    let name = escape(a:name, ' ')
  endif
  return substitute(name, '\(.\{-}\)\[\(.\{-}\)\]\(.\{-}\)', '\1[[]\2[]]\3', 'g')
endfunction " }}}

" ParseArgs(args) {{{
" Parses the supplied argument line into a list of args, handling quoted
" strings, escaped spaces, etc.
function! vcs#util#ParseArgs(args)
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

" GetDefinedSigns() {{{
" Gets a list of defined sign names.
function! vcs#util#GetDefinedSigns()
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

" GetExistingSigns() {{{
" Gets a list of existing signs for the current buffer.
" The list consists of dictionaries with the following keys:
"   id:   The sign id.
"   line: The line number.
"   name: The sign name (erorr, warning, etc.)
"
" Optionally a sign name may be supplied to only retrieve signs of that name.
function! vcs#util#GetExistingSigns(...)
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

" DefineSign(name, text) {{{
" Defines a new sign name or updates an existing one.
function! vcs#util#DefineSign(name, text)
  exec "sign define " . a:name . " text=" . a:text . " texthl=Statement"
endfunction " }}}

" UndefineSign(name) {{{
" Undefines a sign name.
function! vcs#util#UndefineSign(name)
  exec "sign undefine " . a:name
endfunction " }}}

" PlaceSign(name, line) {{{
" Places a sign in the current buffer.
function! vcs#util#PlaceSign(name, line)
  if a:line > 0
    let lastline = line('$')
    let line = a:line <= lastline ? a:line : lastline
    exec "sign place " . line . " line=" . line . " name=" . a:name .
      \ " buffer=" . bufnr('%')
  endif
endfunction " }}}

" UnplaceSign(id) {{{
" Un-places a sign in the current buffer.
function! vcs#util#UnplaceSign(id)
  exec 'sign unplace ' . a:id . ' buffer=' . bufnr('%')
endfunction " }}}

" s:ParseSign(raw) {{{
function! s:ParseSign(raw)
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

" System(cmd, [exec, exec_results]) {{{
" Executes system() accounting for possibly disruptive vim options.
function! vcs#util#System(cmd, ...)
  " on windows, if python is available + exec not requests, use subprocess to
  " avoid the annoying dos cmd console.
  if (has('win32') || has('win64')) &&
   \ (len(a:000) == 0 || !a:000[0]) &&
   \ has('python')
    let cwd = getcwd()
python << PYTHONEOF
import subprocess
import vim

cmd = vim.eval('a:cmd')
startupinfo = subprocess.STARTUPINFO()
startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
process = subprocess.Popen(
  cmd,
  cwd=vim.eval('cwd'),
  stdout=subprocess.PIPE,
  stderr=subprocess.PIPE,
  startupinfo=startupinfo)
error = process.wait() != 0
stdout, stderr = process.communicate()
result = stdout + stderr
vim.command('let result = %s' % ('%r' % result).replace("\\'", "''"))
vim.command('let error = %i' % error)
PYTHONEOF

    " from the above code new lines and tabs will end up as literal \n and \t,
    " so replace them with actual new lines and tabs to that all the code that
    " expects those still works.
    let result = substitute(result, '\\n', '\n', 'g')
    let result = substitute(result, '\\t', '\t', 'g')
    return [error, result]
  endif

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

" s:Cygpath(path) {{{
function! s:Cygpath(path)
  if executable('cygpath')
    let path = substitute(a:path, '\', '/', 'g')
    let [error, path] = vcs#util#System('cygpath "' . path . '"')
    let path = substitute(path, '\n$', '', '')
    return path
  endif
  return a:path
endfunction " }}}

" CommandCompleteRevision(argLead, cmdLine, cursorPos) {{{
" Custom command completion for revisions.
function! vcs#util#CommandCompleteRevision(argLead, cmdLine, cursorPos)
  let cmdLine = strpart(a:cmdLine, 0, a:cursorPos)
  let args = split(cmdLine, '[^\\]\s\zs')
  call map(args, 'substitute(v:val, "\\([^\\\\]\\)\\s\\+$", "\\1", "")')
  let argLead = cmdLine =~ '\s$' ? '' : args[len(args) - 1]

  let revisions = vcs#util#GetRevisions()
  call filter(revisions, 'v:val =~ "^' . argLead . '"')
  return revisions
endfunction " }}}

" vim:ft=vim:fdm=marker
