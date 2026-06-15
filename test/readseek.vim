" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script
nnoremap <Plug>(ReadseekHover) :echo 'keep'<CR>

set nomore
set rtp^=.
runtime plugin/readseek.vim
delete('test-readseek-failures.log')
delete('test-readseek.log')

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

  locations = [{
    file: 'autoload/readseek.vim',
    line: 12,
    column: 1,
    text: 'export def CheckHealth()',
    kind: 'function',
    name: 'CheckHealth',
  }]
  items = readseek#quickfix#ToItems(locations)
  Check('quickfix metadata text', items[0].text ==# '[function] CheckHealth: export def CheckHealth()')
enddef

def TestResultLists()
  var locations = [{file: 'README.md', line: 1, column: 1, text: '# readseek.vim'}]
  edit README.md
  var source_buffer = bufnr('%')

  g:readseek_list_type = 'quickfix'
  readseek#quickfix#SetLocations(locations, 'quickfix test')
  Check('quickfix populated', len(getqflist()) == 1)
  Check('quickfix preserves source buffer', bufnr('%') == source_buffer)
  cclose

  g:readseek_list_type = 'location'
  readseek#quickfix#SetLocations(locations, 'location test')
  Check('location list populated', len(getloclist(0)) == 1)
  Check('location list preserves source buffer', bufnr('%') == source_buffer)
  lclose

  g:readseek_list_type = 'quickfix'
enddef

def TestMappings()
  var gd = maparg('<Plug>(ReadseekDefinition)', 'n', false, true)
  var gr = maparg('<Plug>(ReadseekReferences)', 'n', false, true)
  var hover = maparg('<Plug>(ReadseekHover)', 'n', false, true)
  var rn = maparg('<Plug>(ReadseekRename)', 'n', false, true)
  var search = maparg('<Plug>(ReadseekSearch)', 'n', false, true)
  Check('definition plug mapping', !empty(gd) && gd.rhs ==# '<ScriptCmd>ReadseekDefinition<CR>')
  Check('references plug mapping', !empty(gr) && gr.rhs ==# '<ScriptCmd>ReadseekReferences<CR>')
  Check('hover plug mapping preserved', !empty(hover) && hover.rhs ==# ":echo 'keep'<CR>")
  Check('rename plug mapping', !empty(rn) && rn.rhs ==# '<ScriptCmd>ReadseekRename<CR>')
  Check('search plug mapping', !empty(search) && search.rhs ==# '<ScriptCmd>ReadseekSearch<CR>')
enddef

def TestIdentifyArgs()
  var base = tempname()
  mkdir(base .. '/project', 'p')
  writefile(['alpha beta'], base .. '/project/file.c')
  execute 'edit ' .. fnameescape(base .. '/project/file.c')
  cursor(1, 7)

  var args = readseek#buffer#IdentifyArgs()
  Check('identify command', args[0] ==# 'identify')
  Check('identify stdin path option', index(args, '--stdin') >= 0 && args[index(args, '--stdin') + 1] ==# expand('%:p'))
  Check('identify has no positional target with stdin', count(args, expand('%:p')) == 1)
  Check('identify line option', index(args, '--line') >= 0 && args[index(args, '--line') + 1] ==# '1')
  Check('identify column option', index(args, '--column') >= 0 && args[index(args, '--column') + 1] ==# '7')

  bwipe!
  delete(base, 'rf')
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

def WaitForMessage(text: string): bool
  for _ in range(20)
    if execute('messages') =~# text
      return true
    endif
    sleep 50m
  endfor
  return false
enddef

def TestReferenceFeedback()
  var base = tempname()
  mkdir(base .. '/project/src', 'p')
  writefile(['marker'], base .. '/project/.git')
  writefile(['void target(void) { target(); }'], base .. '/project/src/file.c')

  var executable = base .. '/readseek-fake'
  writefile([
    '#!/bin/sh',
    'if [ "$1" = "identify" ]; then',
    '  printf ''{"identifier":{"text":"target"}}\n''',
    'elif [ "$1" = "refs" ]; then',
    '  printf ''{"locations":[{"file":"src/file.c","line":1,"column":6,"text":"void target(void) { target(); }"},{"file":"src/file.c","line":1,"column":21,"text":"void target(void) { target(); }"}]}\n''',
    '  [ "$2" = "--format" ] && [ "$3" = "plain" ] || exit 2',
    'else',
    '  printf ''{}\n''',
    'fi',
  ], executable)
  setfperm(executable, 'rwx------')

  var save_executable = g:readseek_executable
  var save_root_markers = g:readseek_root_markers
  g:readseek_executable = executable
  g:readseek_root_markers = ['.git']

  execute 'edit ' .. fnameescape(base .. '/project/src/file.c')
  cursor(1, 8)
  readseek#References()

  Check('references start feedback', WaitForMessage('readseek.vim: finding references for target...'))
  Check('references completion feedback', WaitForMessage('readseek.vim: 2 references found for target'))

  g:readseek_executable = save_executable
  g:readseek_root_markers = save_root_markers
  delete(base, 'rf')
enddef

def TestHoverLines()
  var lines = readseek#HoverLines({
    identifier: {text: 'target'},
    symbol: {kind: 'function', name: 'target'},
    file: 'src/file.c',
    line: 1,
    column: 6,
  })

  Check('hover identifier label', index(lines, 'identifier: target') >= 0)
  Check('hover symbol label', index(lines, 'symbol: target') >= 0)
  Check('hover kind label', index(lines, 'kind: function') >= 0)
  Check('hover location label', index(lines, 'location: src/file.c:1:6') >= 0)
enddef

TestQuickfixItems()
TestResultLists()
TestMappings()
TestIdentifyArgs()
TestRootMarkers()
TestHealthCache()
TestReferenceFeedback()
TestHoverLines()

if !empty(failures)
  writefile(failures, 'test-readseek-failures.log')
  cquit
endif

writefile(['ok'], 'test-readseek.log')
qa
