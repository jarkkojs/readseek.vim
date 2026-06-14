" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script
nnoremap <Plug>(ReadseekHover) :echo 'keep'<CR>

set nomore
set rtp^=.
runtime plugin/readseek.vim

var failures: list<string> = []

def Check(name: string, condition: bool)
  if !condition
    add(failures, name)
  endif
enddef

def TestQuickfixItems()
  var locations = [{
    file: 'autoload/readseek.vim',
    line: 3,
    column: 5,
    text: 'import autoload',
  }]
  var items = readseek#quickfix#ToItems(locations)
  Check('quickfix item count', len(items) == 1)
  Check('quickfix filename', items[0].filename ==# 'autoload/readseek.vim')
  Check('quickfix line', items[0].lnum == 3)
  Check('quickfix column', items[0].col == 5)
  Check('quickfix text', items[0].text ==# 'import autoload')
enddef

def TestResultLists()
  var locations = [{file: 'README.md', line: 1, column: 1, text: '# readseek.vim'}]

  g:readseek_list_type = 'quickfix'
  readseek#quickfix#SetLocations(locations, 'quickfix test')
  Check('quickfix populated', len(getqflist()) == 1)

  g:readseek_list_type = 'location'
  readseek#quickfix#SetLocations(locations, 'location test')
  Check('location list populated', len(getloclist(0)) == 1)

  g:readseek_list_type = 'quickfix'
enddef

def TestMappings()
  var gd = maparg('<Plug>(ReadseekDefinition)', 'n', false, true)
  var gr = maparg('<Plug>(ReadseekReferences)', 'n', false, true)
  var hover = maparg('<Plug>(ReadseekHover)', 'n', false, true)
  var rn = maparg('<Plug>(ReadseekRename)', 'n', false, true)
  Check('definition plug mapping', !empty(gd) && gd.rhs ==# '<ScriptCmd>ReadseekDefinition<CR>')
  Check('references plug mapping', !empty(gr) && gr.rhs ==# '<ScriptCmd>ReadseekReferences<CR>')
  Check('hover plug mapping preserved', !empty(hover) && hover.rhs ==# ":echo 'keep'<CR>")
  Check('rename plug mapping', !empty(rn) && rn.rhs ==# '<ScriptCmd>ReadseekRename<CR>')
enddef

def TestRootMarkers()
  var base = tempname()
  mkdir(base .. '/project/src', 'p')
  writefile(['marker'], base .. '/project/.readseek-root')
  writefile(['vim9script'], base .. '/project/src/file.vim')

  g:readseek_root_markers = ['.readseek-root']
  execute 'edit ' .. fnameescape(base .. '/project/src/file.vim')
  Check('custom root marker', readseek#root#Find() ==# base .. '/project')

  g:readseek_root_markers = ['.git']
  delete(base, 'rf')
enddef

def TestHealthCache()
  var save_executable = g:readseek_executable
  g:readseek_executable = 'readseek-cache-a'
  readseek#config#CacheHealth('1.2.3')
  Check('health cache matches executable', readseek#config#IsHealthCached())

  g:readseek_executable = 'readseek-cache-b'
  Check('health cache tracks executable', !readseek#config#IsHealthCached())

  unlet! g:readseek_health
  g:readseek_executable = save_executable
enddef

TestQuickfixItems()
TestResultLists()
TestMappings()
TestRootMarkers()
TestHealthCache()

if !empty(failures)
  writefile(failures, 'test-readseek-failures.log')
  cquit
endif

writefile(['ok'], 'test-readseek.log')
qa
