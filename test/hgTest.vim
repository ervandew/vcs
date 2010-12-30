" Author:  Eric Van Dewoestine
"
" Description: {{{
"   Test case for impl/hg.vim
"
" License:
"
" Copyright (C) 2005 - 2010  Eric Van Dewoestine
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

" SetUp() {{{
function! SetUp()
  let s:test_dir = 'build/test/temp/mercurial/unittest/test'
  exec 'cd ' . s:test_dir
  set expandtab
  set shiftwidth=2 tabstop=2
endfunction " }}}

" TestInfo() {{{
function! TestInfo()
  view file1.txt
  call vunit#PushRedir('@"')
  VcsInfo
  call vunit#PopRedir()
  let info = split(@", '\n')
  call vunit#AssertEquals(info[0], 'changeset:   2:5f0911d194b1')
  call vunit#AssertEquals(info[1], 'user:        ervandew')
  call vunit#AssertEquals(info[2], 'date:        Sat Sep 27 22:31:45 2008 -0700')
  call vunit#AssertEquals(info[3], 'summary:     test a multi line comment')
endfunction " }}}

" TestAnnotate() {{{
function! TestAnnotate()
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
    \ b:vcs_annotations[0],
    \ '6a95632ba43d (Sat Sep 27 22:26:55 2008 -0700) ervandew')

  call cursor(3, 1)
  call vunit#AssertEquals(
    \ b:vcs_annotations[2], '9247ff7b10e3 (Sat Sep 27 22:30:53 2008 -0700) ervandew')

  VcsAnnotateCat
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'vcs_9247ff7b10e3_file1.txt')
  call vunit#AssertEquals(line('$'), 3)
  bdelete

  VcsAnnotateDiff
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'file1.txt')
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_9247ff7b10e3_file1.txt')
  call vunit#AssertEquals(line('$'), 3)
  bdelete

  call vunit#PushRedir('@"')
  VcsAnnotate
  call vunit#PopRedir()
  let existing = vcs#util#GetExistingSigns()
  call vunit#PeekRedir()
  call vunit#AssertEquals(len(existing), 0)
endfunction " }}}

" TestDiff() {{{
function! TestDiff()
  view file1.txt
  call vunit#PeekRedir()
  VcsDiff
  let name = substitute(expand('%'), '\', '/', 'g')
  call vunit#AssertEquals(name, 'file1.txt')
  call vunit#AssertEquals(line('$'), 5)

  winc l

  call vunit#AssertEquals(expand('%'), 'vcs_5f0911d194b1_file1.txt')
  call vunit#AssertEquals(line('$'), 4)
endfunction " }}}

" TestLog() {{{
function! TestLog()
  view file1.txt
  call vunit#PeekRedir()
  VcsLog
  call vunit#AssertEquals(expand('%'), '[vcs_log]')
  call vunit#AssertEquals(getline(1), 'test/file1.txt')
  call vunit#AssertEquals(line('$'), 5)
  call vunit#AssertEquals(getline(3), '+ 5f0911d194b1 ervandew (2008-09-27) test a multi line comment')
  call vunit#AssertEquals(getline(4), '+ 9247ff7b10e3 ervandew (2008-09-27) second revision of files')
  call vunit#AssertEquals(getline(5), '+ 6a95632ba43d ervandew (2008-09-27) adding 2 files')

  " toggle
  call cursor(4, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 9)
  call vunit#AssertEquals(getline(4), '- 9247ff7b10e3 ervandew (2008-09-27) 2008-09-27 22:30 -0700')
  call vunit#AssertEquals(getline(5),'  |view| |annotate| |diff working copy| |diff previous|')
  call vunit#AssertEquals(getline(6), '  second revision of files')
  call vunit#AssertEquals(getline(7), '')
  call vunit#AssertEquals(getline(8), '  + files')

  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 5)
  call vunit#AssertEquals(getline(4), '+ 9247ff7b10e3 ervandew (2008-09-27) second revision of files')

  exec "normal \<cr>"

  " view
  call cursor(5, 4)
  exec "normal \<cr>"
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'vcs_9247ff7b10e3_file1.txt')
  bdelete
  VcsLog

  " annotate
  call cursor(5, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(getline(6), '  |view| |annotate| |diff working copy|')
  call cursor(6, 11)
  exec "normal \<cr>"
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'vcs_6a95632ba43d_file1.txt')
  call vunit#AssertEquals(
    \ b:vcs_annotations[0],
    \ '6a95632ba43d (Sat Sep 27 22:26:55 2008 -0700) ervandew')
  bdelete
  VcsLog

  " diff previous
  call cursor(3, 1)
  exec "normal \<cr>"
  call cursor(4, 42)
  exec "normal \<cr>"
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'vcs_5f0911d194b1_file1.txt')
  call vunit#AssertEquals(line('$'), 4)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_9247ff7b10e3_file1.txt')
  call vunit#AssertEquals(line('$'), 3)
  exec 'bdelete ' . bufnr('vcs_5f0911d194b1_file1.txt')
  exec 'bdelete ' . bufnr('vcs_9247ff7b10e3_file1.txt')
  VcsLog

  " diff working copy
  call vunit#AssertEquals(getline(5), '+ 6a95632ba43d ervandew (2008-09-27) adding 2 files')
  call cursor(5, 1)
  exec "normal \<cr>"
  call cursor(6, 27)
  exec "normal \<cr>"
  call vunit#PeekRedir()
  call vunit#AssertEquals(expand('%'), 'file1.txt', 'Wrong working diff file')
  call vunit#AssertEquals(line('$'), 5)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_6a95632ba43d_file1.txt')
  call vunit#AssertEquals(line('$'), 2)
endfunction " }}}

" TestLogFiles() {{{
function! TestLogFiles()
  view file2.txt
  call vunit#PeekRedir()
  VcsLog
  call vunit#AssertEquals(expand('%'), '[vcs_log]')
  call vunit#AssertEquals(getline(1), 'test/file2.txt')
  call vunit#AssertEquals(line('$'), 6)
  call cursor(3, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(getline(7), '  + files')
  call cursor(7, 1)
  exec "normal \<cr>"

  call vunit#AssertEquals(getline( 7), '  - files')
  call vunit#AssertEquals(getline( 8), '    |M| test/file2.txt')
  call vunit#AssertEquals(getline( 9), '    |A| test/file3.txt')
  call vunit#AssertEquals(getline(10), '    |R| test/file4.txt -> test/file5.txt')

  " modified file
  call cursor(8, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_571c289b2787_file2.txt')
  call vunit#AssertEquals(line('$'), 5)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_5f0911d194b1_file2.txt')
  call vunit#AssertEquals(line('$'), 4)
  bdelete
  bdelete
  winc j

  " new file
  call cursor(9, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_571c289b2787_file3.txt')
  call vunit#AssertEquals(line('$'), 5)
  bdelete
  winc j

  " moved file
  call cursor(10, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_571c289b2787_file5.txt')
  call vunit#AssertEquals(line('$'), 2)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_96e609aeceb3_file4.txt')
  call vunit#AssertEquals(line('$'), 1)
  bdelete
  bdelete
endfunction " }}}

" TestLogGrepMessage() {{{
function! TestLogGrepMessage()
  view file1.txt
  call vunit#PeekRedir()
  VcsLogGrepMessage second\ revision
  call vunit#AssertEquals(expand('%'), '[vcs_log]')
  call vunit#AssertEquals(getline(1), 'pattern: second revision')
  call vunit#AssertEquals(line('$'), 3)
  call vunit#AssertEquals(getline(3),
    \ '+ 9247ff7b10e3 ervandew (2008-09-27) second revision of files')

  call cursor(3, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 6)
  call vunit#AssertEquals(getline(6), '  + files')

  call cursor(6, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 8)
  call vunit#AssertEquals(getline(7), '    |M| test/file1.txt')
  call vunit#AssertEquals(getline(8), '    |M| test/file2.txt')

  call cursor(8, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_9247ff7b10e3_file2.txt')
  call vunit#AssertEquals(line('$'), 3)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_571c289b2787_file2.txt')
  call vunit#AssertEquals(line('$'), 5)
endfunction " }}}

" TestLogGrepFiles() {{{
function! TestLogGrepFiles()
  view file1.txt
  call vunit#PeekRedir()
  VcsLogGrepFiles (second|third)\ revision
  call vunit#AssertEquals(expand('%'), '[vcs_log]')
  call vunit#AssertEquals(getline(1), 'pattern: (second|third) revision')
  call vunit#AssertEquals(line('$'), 5)
  call vunit#AssertTrue(getline(3) =~
    \ '+ 571c289b2787 (tip) ervandew (.*) test copy/move')
  call vunit#AssertEquals(getline(4),
    \ '+ 5f0911d194b1 ervandew (2008-09-27) test a multi line comment')
  call vunit#AssertEquals(getline(5),
    \ '+ 9247ff7b10e3 ervandew (2008-09-27) second revision of files')

  call cursor(4, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 10)
  call vunit#AssertEquals(getline(9), '  + files')

  call cursor(9, 1)
  exec "normal \<cr>"
  call vunit#AssertEquals(line('$'), 12)
  call vunit#AssertEquals(getline(10), '    |M| test/file1.txt')
  call vunit#AssertEquals(getline(11), '    |M| test/file2.txt')

  call cursor(11, 6)
  exec "normal \<cr>"
  call vunit#AssertEquals(expand('%'), 'vcs_5f0911d194b1_file2.txt')
  call vunit#AssertEquals(line('$'), 4)
  winc l
  call vunit#AssertEquals(expand('%'), 'vcs_9247ff7b10e3_file2.txt')
  call vunit#AssertEquals(line('$'), 3)
endfunction " }}}

" vim:ft=vim:fdm=marker
