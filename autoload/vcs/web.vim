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

if !exists('g:vcs_web_loaded')
  let g:vcs_web_loaded = 1
else
  finish
endif

" Script Variables {{{
  let s:vcs_viewers = {
      \ 'trac': 'http://${host}/${path}',
      \ 'redmine': 'http://${host}/repositories/<cmd>/${path}',
      \ 'hgcgi': 'http://${host}/${path}',
      \ 'hgserve': 'http://${host}/${path}',
      \ 'gitweb': 'http://${host}/git/gitweb.cgi?p=${path}',
      \ 'github': 'http://github.com/${username}/${project}',
      \ 'bitbucket': 'http://bitbucket.org/${username}/${project}',
      \ 'googlecode': 'http://code.google.com/p/${project}',
    \ }

  let s:vcs_viewer_saved = {}

  let s:win_browsers = [
      \ 'C:/Program Files/Opera/Opera.exe',
      \ 'C:/Program Files/Mozilla Firefox/firefox.exe',
      \ 'C:/Program Files/Internet Explorer/iexplore.exe'
    \ ]

  let s:browsers = [
      \ 'xdg-open', 'opera', 'firefox', 'konqueror',
      \ 'epiphany', 'mozilla', 'netscape', 'iexplore'
    \ ]
" }}}

" GetVcsWebFunction(type, func_name) {{{
" Gets a reference to the proper vcs web function.
" Ex. let GetLogUrl = vcs#web#GetVcsWebFunction('github', 'GetLogUrl')
function vcs#web#GetVcsWebFunction(type, func_name)
  try
    return function('vcs#impl#' . a:type . '#' . a:func_name)
  catch /E700:.*/
    call vcs#util#EchoError('This function is not supported by "' . a:type . '".')
    return
  endtry
endfunction " }}}

" VcsWeb(url_func, ...) {{{
function vcs#web#VcsWeb(url_func, ...)
  let vcs = vcs#util#GetVcsType()
  if vcs == ''
    return
  endif

  let settings = vcs#util#GetSettings()
  let viewer = get(settings, 'web_viewer', '')
  let url = get(settings, 'web_url', '')

  if viewer == '' || url == ''
    let viewer = get(s:vcs_viewer_saved, 'viewer', viewer)
    let url = get(s:vcs_viewer_saved, 'url', url)
    let prompt = 1

    if url == ''
      let response = vcs#util#PromptConfirm(
        \ "VcsWeb commands require that the 'web_viewer' and 'web_url'\n" .
        \ "settings for your repository be set in g:VcsRepositorySettings.\n" .
        \ "Would you like to temporarily supply these values?")
      if response != 1
        return
      endif
    else
      let response = vcs#util#PromptConfirm(
        \ "Using values\n" .
        \ "  viewer: " . viewer . "\n" .
        \ "     url: " . url . "\n" .
        \ "Continue using these values?")
      let prompt = response != 1
    endif

    if prompt
      " TODO: maybe filter types by the vcs
      let types = sort(keys(s:vcs_viewers))
      let response = vcs#util#PromptList(
        \ 'Choose the appropriate web viewer', types)
      if response < 0
        return
      endif

      let viewer = types[response]
      let url = s:vcs_viewers[viewer]
      let vars = split(substitute(url, '.\{-}\(\${\w\+}\).\{-}\|.*', '\1 ', 'g'))
      echohl Statement
      try
        for var in vars
          redraw
          echo "Building url: " . url . "\n"
          let varname = substitute(var, '\${\|}', '', 'g')
          let response = input("Please enter the " . varname . ": ")
          if response == ''
            return
          endif
          let url = substitute(url, var, response, '')
        endfor
      finally
        echohl None
      endtry

      let s:vcs_viewer_saved = {'viewer': viewer, 'url': url}
    endif
  endif

  if url =~ '/$'
    let url = url[:-2]
  elseif type(url) == 0 && url == 0
    return
  endif

  let path = exists('b:filename') ? b:filename : expand('%:p')
  let root = vcs#util#GetRoot(path)
  let path = vcs#util#GetRelativePath(path)
  if root == ''
    call vcs#util#EchoError('Current file is not under a supported version control.')
    return
  endif

  let GetUrl = vcs#web#GetVcsWebFunction(viewer, a:url_func)
  if type(GetUrl) != 2
    return
  endif
  let url = GetUrl(url, path, a:000)
  if url == '0'
    return
  endif

  call vcs#web#OpenUrl(url)
endfunction " }}}

" VcsWebLog(revision) {{{
" View the vcs web log.
function vcs#web#VcsWebLog(revision)
  let revision = a:revision
  if revision == ''
    let path = exists('b:filename') ? b:filename : expand('%:p')
    let path = vcs#util#GetRelativePath(path)
    let revision = vcs#util#GetRevision(path)
  endif
  call vcs#web#VcsWeb('GetLogUrl', revision)
endfunction " }}}

" VcsWebChangeSet(revision) {{{
" View the revision info for the supplied or current revision of the
" current file.
function vcs#web#VcsWebChangeSet(revision)
  let revision = a:revision
  if revision == ''
    let path = exists('b:filename') ? b:filename : expand('%:p')
    let revision = vcs#util#GetRevision(path)
  endif

  call vcs#web#VcsWeb('GetChangeSetUrl', revision)
endfunction " }}}

" VcsWebAnnotate(revision) {{{
" View annotated version of the file.
function vcs#web#VcsWebAnnotate(revision)
  let revision = a:revision
  if revision == ''
    let path = vcs#util#GetRelativePath()
    let revision = vcs#util#GetRevision(path)
  endif

  call vcs#web#VcsWeb('GetAnnotateUrl', revision)
endfunction " }}}

" VcsWebDiff(revision1, revision2) {{{
" View diff between two revisions.
function vcs#web#VcsWebDiff(...)
  let args = a:000
  if len(args) == 1
    let args = split(args[0])
  endif

  if len(args) > 2
    call vcs#util#EchoWarning(":VcsWebDiff accepts at most 2 revision arguments.")
    return
  endif

  let path = vcs#util#GetRelativePath()
  let revision1 = len(args) > 0 ? args[0] : ''
  if revision1 == ''
    let revision1 = vcs#util#GetRevision(path)
  endif

  let revision2 = len(args) > 1 ? args[1] : ''
  if revision2 == ''
    let revision2 = len(args) == 1 ?
      \ vcs#util#GetRevision(path) : vcs#util#GetPreviousRevision(path)
    if revision2 == '0'
      call vcs#util#EchoWarning(
        \ "File '" . expand('%') . "' has no previous revision to diff.")
      return
    endif
  endif

  call vcs#web#VcsWeb('GetDiffUrl', revision1, revision2)
endfunction " }}}

" OpenUrl(url) {{{
" Opens the supplied url in a web browser.
function! vcs#web#OpenUrl(url)
  if !exists('s:browser') || s:browser == ''
    let s:browser = s:DetermineBrowser()

    " slight hack for IE which doesn't like the url to be quoted.
    if s:browser =~ 'iexplore' && !has('win32unix')
      let s:browser = substitute(s:browser, '"', '', 'g')
    endif
  endif

  if s:browser == '' || a:url == ''
    return
  endif

  let url = a:url
  let url = substitute(url, '\', '/', 'g')
  let url = escape(url, '&%!')
  let url = escape(url, '%!')
  let command = escape(substitute(s:browser, '<url>', url, ''), '#')
  silent call vcs#util#System(command, 1)
  redraw!

  if v:shell_error
    call vcs#util#EchoError("Unable to open browser:\n" . s:browser .
      \ "\nCheck that the browser executable is in your PATH " .
      \ "or that you have properly configured g:VcsBrowser")
  endif
endfunction " }}}

" s:DetermineBrowser() {{{
function! s:DetermineBrowser()
  let browser = ''

  " user specified a browser, we just need to fill in any gaps if necessary.
  if exists("g:VcsBrowser")
    let browser = g:VcsBrowser
    " add "<url>" if necessary
    if browser !~ '<url>'
      let browser = substitute(browser,
        \ '^\([[:alnum:][:blank:]-/\\_.:"]\+\)\(.*\)$',
        \ '\1 "<url>" \2', '')
    endif

    if has("win32") || has("win64")
      " add 'start' to run process in background if necessary.
      if browser !~ '^[!]\?start'
        let browser = 'start ' . browser
      endif
    else
      " add '&' to run process in background if necessary.
      if browser !~ '&\s*$' &&
       \ browser !~ '^\(/[/a-zA-Z0-9]\+/\)\?\<\(links\|lynx\|elinks\|w3m\)\>'
        let browser = browser . ' &'
      endif

      " add redirect of std out and error if necessary.
      if browser !~ '/dev/null'
        let browser = substitute(browser, '\s*&\s*$', '&> /dev/null &', '')
      endif
    endif

    if browser !~ '^\s*!'
      let browser = '!' . browser
    endif

  " user did not specify a browser, so attempt to find a suitable one.
  else
    if has('win32') || has('win64') || has('win32unix')
      " Note: this version may not like .html suffixes on windows 2000
      if executable('rundll32')
        let browser = 'rundll32 url.dll,FileProtocolHandler <url>'
      endif
      " this doesn't handle local files very well or '&' in the url.
      "let browser = '!cmd /c start <url>'
      if browser == ''
        for name in s:win_browsers
          if has('win32unix')
            let name = s:Cygpath(name)
          endif
          if executable(name)
            let browser = name
            if has('win32unix')
              let browser = '"' . browser . '"'
            endif
            break
          endif
        endfor
      endif
    elseif has('mac')
      let browser = '!open <url>'
    else
      for name in s:browsers
        if executable(name)
          let browser = name
          break
        endif
      endfor
    endif

    if browser != ''
      let g:VcsBrowser = browser
      let browser = s:DetermineBrowser()
    endif
  endif

  if browser == ''
    call vcs#util#EchoError("Unable to determine browser.  " .
      \ "Please set g:VcsBrowser to your preferred browser.")
  endif

  return browser
endfunction " }}}

" vim:ft=vim:fdm=marker
