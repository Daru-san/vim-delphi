"=============================================================================
" File:          delphi.vim
" Author:        Mattia72 
" Description:   plugin definitions
" Created:       16.03.2019
" Project Repo:  https://github.com/Mattia72/delphi
" License:       MIT license  {{{
"   Permission is hereby granted, free of charge, to any person obtaining
"   a copy of this software and associated documentation files (the
"   "Software"), to deal in the Software without restriction, including
"   without limitation the rights to use, copy, modify, merge, publish,
"   distribute, sublicense, and/or sell copies of the Software, and to
"   permit persons to whom the Software is furnished to do so, subject to
"   the following conditions:
"
"   The above copyright notice and this permission notice shall be included
"   in all copies or substantial portions of the Software.
"
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

scriptencoding utf-8

" Preprocessing
if exists('g:loaded_delphi_vim')
  finish
elseif v:version < 700
  echoerr 'vim-delphi does not work this version of Vim "' . v:version . '".'
  finish
endif

let g:loaded_delphi_vim = 1

let s:save_cpo = &cpo
set cpo&vim

" ----------------------
" Global options 
" ----------------------

set mouse=a     "Enables mouse click

let delphi_space_errors = 1
let delphi_leading_space_error = 1
"let  delphi_leading_tab_error = 1
let delphi_trailing_space_error = 1
let delphi_highlight_function_parameters = 1

let g:delphi_build_config = 'Debug'

" ----------------------
" Functions
" ----------------------

function! g:delphi#SwitchPasOrDfm()
  if (expand ("%:e") == "pas")
    find %:t:r.dfm
  else
    find %:t:r.pas
  endif
endfunction

function! g:delphi#OpenAndHighlightQuickFix()
  copen  
  "http://docwiki.embarcadero.com/RADStudio/Rio/en/Error_and_Warning_Messages_(Delphi)
  syn match qfInfo "^||.*" 
  syn match qfErrorMsg " \zs\w\+ [EF]\d\{4}\ze:" 
  syn match qfErrorMsg " \zsLinker error\ze:" 
  syn match qfWarningMsg " \zs\w\+ [WH]\d\{4}\ze:"
  hi def link qfInfo Delimiter
  hi def link qfErrorMsg ErrorMsg
  hi def link qfWarningMsg  WarningMsg 
  wincmd J       
endfunction

function! g:delphi#SetProjectSearchPath()
  if exists('g:delphi_project_path')
    " don't worry, nothing will be added twice :)
    execute 'set path+='.escape(g:delphi_project_path,' \|')
  endif
endfunction

function! g:delphi#FindProject(...)
  let active_file_dir = expand('%:p:h')
  let project_file = ''
  if a:0 != 0 && !empty(a:1)
    let project_name =  a:1
    redraw | echom 'Search '.project_name.' in path '.&path
    " find file in path 
    " set path +=...
    call delphi#SetProjectSearchPath()
    " faster if we are in the dir
    let project_file = findfile(project_name)
  else
    let cwd_orig = getcwd()
    let project_name = '*.dproj'
    while getcwd() =~ '^\[A-Z\]:\\\\$'
      redraw | echom 'Search downwards in '.getcwd()
      " find downwards 
      let project_file = globpath('.', "*.dproj") 
      if !empty(project_file) | break | else | chdir .. | endif
    endwhile
    execute 'chdir '.cwd_orig
  endif
  redraw
  if !empty(project_file) | return project_file | else | return 0 | endif
endfunction

function! g:delphi#SetSavedProject(...)
  let g:delphi_saved_project = ''

  if a:0 != 0 && !empty(a:1)
    let project_name = a:1
  else
    call inputsave()
    let project_name = input('Save project for later use (*.dproj): ') 
    call inputrestore()
  endif

  "while !empty(glob(g:delphi_saved_project))
  call delphi#SetProjectSearchPath()
  let g:delphi_saved_project = findfile(project_name)
  if empty(g:delphi_saved_project)
	  echohl ErrorMsg | redraw | echom 'Can''t find project "'.project_name.'". Set path or g:delphi_project_path and try again!' | echohl None
	  unlet g:delphi_saved_project
  endif
  "endwhile
  redraw
endfunction

function! g:delphi#FindAndMake(...)
  if a:0 != 0 && !empty(a:1)
    let project_name =  a:1
    let project_file = delphi#FindProject(project_name)
  else
    let project_name = '*.dproj'
    let project_file = delphi#FindProject()
  endif
  "echom 'FindAndMake args: '.a:0.' "'.project_name.'" found: '.project_file
  if !empty(project_file) 
	  echohl WarningMsg | echo 'Make '.project_file | echohl None

    execute 'make! /p:config='.g:delphi_build_config.' '.project_file 
    if len(getqflist()) > 0
      call delphi#OpenAndHighlightQuickFix()
    endif
  else  
	  echohl ErrorMsg | redraw | echom 'Can''t find project "'.project_name.'"' | echohl None
  endif
endfunction

function! g:delphi#SaveProjectAndMake(...)

  if a:0 != 0 && !empty(a:1)
    "echom 'set saved '.a:1
    call delphi#SetSavedProject(a:1) 
  else
    if !exists('g:delphi_saved_project') || empty(g:delphi_saved_project) 
      " ask for project name ...
      call delphi#SetSavedProject() 
    endif                    
  endif

  if exists('g:delphi_saved_project') && !empty(glob(g:delphi_saved_project))
    call delphi#FindAndMake(g:delphi_saved_project)
  "else
		"echohl ErrorMsg | redraw | echom 'g:delphi_saved_project doesn''t defined properly.' | echohl None
  endif

endfunction

function! g:delphi#SetBuildConfig(config)
  if a:0 != 0 && !empty(a:1)
    let g:delphi_build_config = a:config
  endif
endfunction

" ----------------------
" Autocommands
" ----------------------

augroup delphi_vim_global_command_group
  autocmd!
  autocmd FileType delphi nnoremap <buffer> <F7> :wa<bar>call delphi#SaveProjectAndMake()<bar>cwindow<CR>
  autocmd FileType delphi command! -nargs=0 DelphiSwitchToDfm call delphi#SwitchPasOrDfm()
  autocmd FileType delphi command! -nargs=0 DelphiSwitchToPas call delphi#SwitchPasOrDfm()
augroup END

" ----------------------
" Commands
" ----------------------
 
command! -nargs=* -complete=file_in_path DelphiMakeSaved call delphi#SaveProjectAndMake(<f-args>)
command! -nargs=* -complete=file_in_path DelphiMake call delphi#FindAndMake(<q-args>)
command! -nargs=+ DelphiSetBuildConfig call delphi#SetBuildConfig(<q-args>)

" ----------------------
" Mappings
" ----------------------

" select inside a begin-end block with vif or vaf
vnoremap af :<C-U>silent! normal! [zV]z<CR>
vnoremap if :<C-U>silent! normal! [zjV]zk<CR>
omap af :normal Vaf<CR>
omap if :normal Vif<CR>

"FIXME read tabularize.doc for extension
if exists(':Tabularize') " Align selected assignes in nice columns with plugin
  vnoremap <leader>t= :Tabularize /:=<CR>
  vnoremap <leader>t: :Tabularize /:<CR>
endif

if exists(':RainbowToggle')
  let delphi_rainbow_conf = {
	      \	'separately': {
	      \		'delphi': {
	      \			'parentheses': ['start=/(/ end=/)/', 'start=/\[/ end=/\]/', 'start=/begin/ end=/end/'],
	      \		},
	      \	}
	      \}
  if exists('g:rainbow_conf')
	  call extend(g:rainbow_conf, delphi_rainbow_conf)
	else
	  let g:rainbow_conf = delphi_rainbow_conf
	endif
endif

" highlight selcted word
nnoremap <silent> <2-LeftMouse> :let @/='\V\<'.escape(expand('<cword>'), '\').'\>'<cr>:set hls<cr>

let &cpo = s:save_cpo
unlet s:save_cpo
