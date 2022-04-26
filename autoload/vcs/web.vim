" Author:  Eric Van Dewoestine
"
" License: {{{
"   Copyright (c) 2005 - 2022, Eric Van Dewoestine
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
      \ 'jira': 'https://${host}/browse/${issue}',
      \ 'trac': 'http://${host}/${path}',
      \ 'redmine': 'http://${host}/repositories/<cmd>/${path}',
      \ 'gitweb': 'http://${host}/git/gitweb.cgi?p=${path}',
      \ 'github': 'http://github.com/${username}/${project}',
      \ 'bitbucket': 'http://bitbucket.org/${username}/${project}',
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

function! vcs#web#OpenUrl(url) " {{{
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

function! s:DetermineBrowser() " {{{
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
