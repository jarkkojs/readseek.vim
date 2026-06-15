" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script

if exists('g:loaded_readseek')
  finish
endif
g:loaded_readseek = true

if !exists('g:readseek_executable')
  g:readseek_executable = 'readseek'
endif

if !exists('g:readseek_root_markers')
  g:readseek_root_markers = ['.git']
endif
if !exists('g:readseek_list_type')
  g:readseek_list_type = 'quickfix'
endif

command! ReadseekCheckHealth readseek#CheckHealth()
command! ReadseekHover readseek#Hover()
command! ReadseekDefinition readseek#Definition()
command! ReadseekReferences readseek#References()
command! ReadseekRename readseek#Rename()
command! ReadseekSearch readseek#Search()

def MapPlugDefault(lhs: string, rhs: string)
  if !empty(maparg(lhs, 'n'))
    return
  endif
  execute $'nnoremap <silent> {lhs} {rhs}'
enddef

MapPlugDefault('<Plug>(ReadseekDefinition)', '<ScriptCmd>ReadseekDefinition<CR>')
MapPlugDefault('<Plug>(ReadseekReferences)', '<ScriptCmd>ReadseekReferences<CR>')
MapPlugDefault('<Plug>(ReadseekHover)', '<ScriptCmd>ReadseekHover<CR>')
MapPlugDefault('<Plug>(ReadseekRename)', '<ScriptCmd>ReadseekRename<CR>')

highlight default ReadseekOk ctermfg=green guifg=#00d700
highlight default ReadseekInfo ctermfg=blue guifg=#5f87af
highlight default ReadseekWarn ctermfg=yellow guifg=#d7d700
highlight default ReadseekError ctermfg=red guifg=#d70000
highlight default ReadseekBorder ctermfg=blue guifg=#5f87af
highlight default ReadseekTitle cterm=bold ctermfg=blue gui=bold guifg=#5f87af
