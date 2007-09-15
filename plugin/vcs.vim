" Author:  Eric Van Dewoestine
" Version: $Revision$
"
" Description: {{{
"   Commands for working with version control systems.
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

" Command Declarations {{{
if !exists(":VcsAnnotate")
  command VcsAnnotate :call eclim#vcs#Annotate()
  command VcsAnnotateOff :call eclim#vcs#AnnotateOff()
endif
if !exists(":Viewvc")
  command -nargs=? -complete=customlist,eclim#project#util#CommandCompleteProjectRelative
    \ Viewvc :call eclim#vcs#Viewvc('<args>', 'view=log')
endif
if !exists(":ViewvcChangeSet")
  command -nargs=? -complete=customlist,eclim#vcs#CommandCompleteRevision
    \ ViewvcChangeSet :call eclim#vcs#ViewvcChangeSet(<q-args>)
endif
if !exists(":ViewvcAnnotate")
  command -nargs=? -complete=customlist,eclim#vcs#CommandCompleteRevision
    \ ViewvcAnnotate :call eclim#vcs#ViewvcAnnotate(<q-args>)
endif
if !exists(":ViewvcDiff")
  command -nargs=* -complete=customlist,eclim#vcs#CommandCompleteRevision
    \ ViewvcDiff :call eclim#vcs#ViewvcDiff(<q-args>)
endif
" }}}

" vim:ft=vim:fdm=marker
