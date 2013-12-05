" Author:  Eric Van Dewoestine
"
" Description: {{{
"   Test case for impl/git.vim
"
" License:
"
" Copyright (C) 2005 - 2013  Eric Van Dewoestine
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
" }}}

function! SetUp() " {{{
  let s:test_dir = 'build/test/temp/git/unittest/test'
  exec 'cd ' . s:test_dir
  set expandtab
  set shiftwidth=2 tabstop=2
endfunction " }}}

function! TestInfo() " {{{
  view file1.txt
  call vunit#PushRedir('@"')
  VcsInfo
  call vunit#PopRedir()
  let info = split(@", '\n')
  call vunit#AssertEquals(info[0], 'commit 101e4be405fdf4f4c38e5b0e3726e937559037f3')
  call vunit#AssertEquals(info[1], 'Author: ervandew <ervandew@gmail.com>')
  call vunit#AssertEquals(info[2], 'Date:   Sat Sep 27 18:05:24 2008 -0700')
  call vunit#AssertEquals(info[3], '')
  call vunit#AssertEquals(info[4], '    changed some files and leaving a multi line comment')
  call vunit#AssertEquals(info[5], '    ')
  call vunit#AssertEquals(info[6], '    - file 1')
  call vunit#AssertEquals(info[7], '    - file 2')

endfunction " }}}

function! TestAnnotate() " {{{
  view file1.txt
  call vunit#PeekRedir()
  call vunit#PushRedir('@"')
  VcsAnnotate
  call vunit#PopRedir()
  let existing = vcs#util#GetExistingSigns()
  call vunit#PeekRedir()
  call vunit#AssertEquals(len(existing), 4)
  call vunit#AssertEquals(existing[0].name, 'vcs_annotate_ervand')

  call vunit#AssertEquals(
    \ b:vcs_annotations[0], 'df552e02 (2008-09-27 13:49:08 -0700) ervandew')

  call cursor(3, 1)
  call vunit#AssertEquals(
    \ b:vcs_annotations[2], '08c4100b (2008-09-27 15:01:49 -0700) ervandew')

  VcsAnnotateCat
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'vcs_08c4100b_file1.txt')
  call vunit#AssertEquals(line('$'), 3)
  bdelete

  VcsAnnotateDiff
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'file1.txt')
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_08c4100b_file1.txt')
  call vunit#AssertEquals(line('$'), 3)
  bdelete

  call vunit#PushRedir('@"')
  VcsAnnotate
  call vunit#PopRedir()
  let existing = vcs#util#GetExistingSigns()
  call vunit#PeekRedir()
  call vunit#AssertEquals(len(existing), 0)
endfunction " }}}

function! TestDiff() " {{{
  view file1.txt
  call vunit#PeekRedir()
  VcsDiff
  let name = substitute(expand('%'), '\', '/', 'g')
  call vunit#AssertEquals(name, 'file1.txt')
  call vunit#AssertEquals(line('$'), 5)

  winc l

  call vunit#AssertEquals(
    \ expand('%'), 'vcs_101e4be_file1.txt')
  call vunit#AssertEquals(line('$'), 4)
endfunction " }}}

function! TestLog() " {{{
  view file1.txt
  call vunit#PeekRedir()
  VcsLog
  call vunit#AssertEquals(expand('%'), '[vcs_log]')
  call vunit#AssertEquals(getline(1), 'test/file1.txt')
  call vunit#AssertEquals(line('$'), 5)
  call vunit#AssertTrue(
    \ getline(3) =~
    \ '+ 101e4be ervandew (.* ago) changed some files and leaving a multi line comment')
  call vunit#AssertTrue(
    \ getline(4) =~
    \ '+ 08c4100 ervandew (.* ago) added 2nd revision content to file1.txt')
  call vunit#AssertTrue(
    \ getline(5) =~
    \ '+ df552e0 ervandew (.* ago) adding some test files')

  " toggle
  call cursor(4, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 9)
  call vunit#AssertTrue(
    \ getline(4) =~
    \ '- 08c4100 ervandew (.* ago) 2008-09-27 15:01:49 -0700')
  call vunit#AssertEquals(
    \ getline(5),
    \ '  |view| |annotate| |diff working copy| |diff previous|')
  call vunit#AssertEquals(getline(6), '  added 2nd revision content to file1.txt')
  call vunit#AssertEquals(getline(7), '')
  call vunit#AssertEquals(getline(8), '  + files')

  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 5)
  call vunit#AssertTrue(
    \ getline(4) =~
    \ '+ 08c4100 ervandew (.* ago) added 2nd revision content to file1.txt')

  exec "normal \<cr>"

  " view
  call cursor(5, 4)
  exec "normal \<cr>"
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'vcs_08c4100_file1.txt')
  bdelete
  VcsLog

  " annotate
  call cursor(5, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(getline(6), '  |view| |annotate| |diff working copy|')
  call cursor(6, 11)
  exec "normal \<cr>"
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'vcs_df552e0_file1.txt')
  call vunit#AssertEquals(
    \ b:vcs_annotations[0], 'df552e02 (2008-09-27 13:49:08 -0700) ervandew')
  bdelete
  VcsLog

  " diff previous
  call cursor(3, 1)
  exec "normal \<cr>"
  call cursor(4, 42)
  exec "normal \<cr>"
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'vcs_101e4be_file1.txt')
  call vunit#AssertEquals(line('$'), 4)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_08c4100_file1.txt')
  call vunit#AssertEquals(line('$'), 3)
  bdelete
  bdelete
  VcsLog

  " diff working copy
  call cursor(5, 1)
  exec "normal \<cr>"
  call cursor(6, 27)
  exec "normal \<cr>"
  call vunit#PeekRedir()
  let name = substitute(expand('%'), '\', '/', 'g')
  call vunit#AssertEquals(name, 'file1.txt')
  call vunit#AssertEquals(line('$'), 5)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_df552e0_file1.txt')
  call vunit#AssertEquals(line('$'), 2)
endfunction " }}}

function! TestLogFiles() " {{{
  view file2.txt
  call vunit#PeekRedir()
  VcsLog
  call vunit#AssertEquals(expand('%'), '[vcs_log]')
  call vunit#AssertEquals(getline(1), 'test/file2.txt')
  call vunit#AssertEquals(line('$'), 5)
  call cursor(3, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(getline(7), '  + files')
  call cursor(7, 1)
  exec "normal \<cr>"

  call vunit#AssertEquals(getline( 7), '  - files')
  call vunit#AssertEquals(getline( 8), '    |M| test/file2.txt')
  call vunit#AssertEquals(getline( 9), '    |A| test/file3.txt')
  " I'm not sure why, but on windows, git is not picking up the rename
  if has('win32') || has('win64')
    call vunit#AssertEquals(getline(10), '    |D| test/file4.txt')
    call vunit#AssertEquals(getline(11), '    |A| test/file5.txt')
  else
    call vunit#AssertEquals(getline(10), '    |R| test/file4.txt -> test/file5.txt')
  endif

  " modified file
  call cursor(8, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_ee5a562_file2.txt')
  call vunit#AssertEquals(line('$'), 4)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_101e4be_file2.txt')
  call vunit#AssertEquals(line('$'), 3)
  bdelete
  bdelete
  winc j

  " new file
  call cursor(9, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_ee5a562_file3.txt')
  call vunit#AssertEquals(line('$'), 4)
  bdelete
  winc j

  " moved file
  if !has('win32') && !has('win64') " continuation of the windows issue
    call cursor(10, 6)
    exec "normal \<cr>"
    call vunit#AssertEquals(expand('%'), 'vcs_ee5a562_file5.txt')
    call vunit#AssertEquals(line('$'), 1)
    winc l
    call vunit#AssertEquals(expand('%'), 'vcs_35a1f6a_file4.txt')
    call vunit#AssertEquals(line('$'), 1)
    bdelete
    bdelete
  endif
endfunction " }}}

function! TestLogGrepMessage() " {{{
  view file1.txt
  call vunit#PeekRedir()
  if has('win32') || has('win64')
    " i can't seem to figure out the dos magic to get git to recognize a \b
    VcsLogGrepMessage add.*file[s]?
    call vunit#AssertEquals(expand('%'), '[vcs_log]')
    call vunit#AssertEquals(getline(1), 'pattern: add.*file[s]?')
    call vunit#AssertEquals(line('$'), 5)
    call vunit#AssertTrue(getline(3) =~ '+ 35a1f6a ervandew (.* ago) add file 4')
    call vunit#AssertTrue(getline(4) =~ '+ 08c4100 ervandew (.* ago) added 2nd revision content to file1.txt')
    call vunit#AssertTrue(getline(5) =~ '+ df552e0 ervandew (.* ago) adding some test files')
  else
    VcsLogGrepMessage add.*file[s]?\\b
    call vunit#AssertEquals(expand('%'), '[vcs_log]')
    call vunit#AssertEquals(getline(1), 'pattern: add.*file[s]?\b')
    call vunit#AssertEquals(line('$'), 4)
    call vunit#AssertTrue(getline(3) =~ '+ 35a1f6a ervandew (.* ago) add file 4')
    call vunit#AssertTrue(getline(4) =~ '+ df552e0 ervandew (.* ago) adding some test files')
  endif

  call cursor(3, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(getline(6), '  + files')

  call cursor(6, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(getline(7), '    |A| test/file4.txt')

  call cursor(7, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_35a1f6a_file4.txt')
  call vunit#AssertEquals(line('$'), 1)
  call vunit#AssertEquals(getline(1), 'file 4')
endfunction " }}}

function! TestLogGrepFiles() " {{{
  view file1.txt
  call vunit#PeekRedir()
  VcsLogGrepFiles (second|third)\ revision
  call vunit#AssertEquals(expand('%'), '[vcs_log]')
  call vunit#AssertEquals(getline(1), 'pattern: (second|third) revision')
  call vunit#AssertEquals(line('$'), 5)
  call vunit#AssertTrue(getline(3) =~
    \ '+ ee5a562 (HEAD, master) ervandew (.* ago) test modification + move')
  call vunit#AssertTrue(getline(4) =~
    \ '+ 101e4be ervandew (.* ago) changed some files and leaving a multi line comment')
  call vunit#AssertTrue(getline(5) =~
    \ '+ 08c4100 ervandew (.* ago) added 2nd revision content to file1.txt')

  call cursor(4, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 11)
  call vunit#AssertEquals(getline(10), '  + files')

  call cursor(10, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 13)
  call vunit#AssertEquals(getline(11), '    |M| test/file1.txt')
  call vunit#AssertEquals(getline(12), '    |M| test/file2.txt')

  call cursor(12, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_101e4be_file2.txt')
  call vunit#AssertEquals(line('$'), 3)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_df552e0_file2.txt')
  call vunit#AssertEquals(line('$'), 2)
endfunction " }}}

" vim:ft=vim:fdm=marker
