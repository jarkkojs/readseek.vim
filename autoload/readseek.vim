" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script

import autoload 'readseek/buffer.vim'
import autoload 'readseek/config.vim'
import autoload 'readseek/job.vim'
import autoload 'readseek/quickfix.vim'
import autoload 'readseek/root.vim'

export def CheckHealth()
  var result = config.CheckHealth()
  if result.ok
    echo result.message
  else
    Error(result.message)
  endif
enddef

export def Hover()
  Identify((result: dict<any>) => {
    if !result.ok
      Error(get(result, 'error', 'readseek identify failed'))
      return
    endif

    var lines = HoverLines(result.json)
    if empty(lines)
      echo 'readseek.vim: no identifier at cursor'
      return
    endif

    ShowHover(lines)
  })
enddef

export def Definition()
  Identify((identify_result: dict<any>) => {
    if !identify_result.ok
      Error(get(identify_result, 'error', 'readseek identify failed'))
      return
    endif

    job.Run(['definition', '--stdin', '--compact', root.Find()], identify_result.stdout, (definition_result: dict<any>) => {
      if !definition_result.ok
        Error(get(definition_result, 'error', 'readseek definition failed'))
        return
      endif
      HandleDefinitionLocations(get(definition_result.json, 'locations', []))
    })
  })
enddef

export def References()
  Identify((identify_result: dict<any>) => {
    if !identify_result.ok
      Error(get(identify_result, 'error', 'readseek identify failed'))
      return
    endif

    var identifier_text = IdentifierText(identify_result.json)
    if empty(identifier_text)
      echo 'readseek.vim: no identifier at cursor'
      return
    endif

    var project_root = root.Find()
    job.Run(['references', '--compact', project_root, identifier_text], '', (references_result: dict<any>) => {
      if !references_result.ok
        Error(get(references_result, 'error', 'readseek references failed'))
        return
      endif

      var locations = get(references_result.json, 'locations', [])
      if empty(locations)
        echo $'readseek.vim: no references found for {identifier_text}'
        return
      endif

      for location in locations
        location.file = ResolveLocationFile(get(location, 'file', ''), project_root)
      endfor
      quickfix.SetLocations(locations, $'readseek references: {identifier_text}')
    })
  })
enddef

export def Rename()
  Identify((identify_result: dict<any>) => {
    if !identify_result.ok
      Error(get(identify_result, 'error', 'readseek identify failed'))
      return
    endif

    var old_name = IdentifierText(identify_result.json)
    if empty(old_name)
      echo 'readseek.vim: no identifier at cursor'
      return
    endif

    var new_name = input($'Rename {old_name} to: ', old_name)
    if empty(new_name) || new_name ==# old_name
      return
    endif

    var project_root = root.Find()
    job.Run(['references', '--compact', project_root, old_name], '', (references_result: dict<any>) => {
      if !references_result.ok
        Error(get(references_result, 'error', 'readseek references failed'))
        return
      endif

      var locations = get(references_result.json, 'locations', [])
      if empty(locations)
        echo $'readseek.vim: no references found for {old_name}'
        return
      endif

      ApplyRename(locations, old_name, new_name, project_root)
    })
  })
enddef

export def Identify(Callback: func)
  job.Run(buffer.IdentifyArgs(), buffer.Stdin(), Callback)
enddef

def IdentifierText(identify: dict<any>): string
  var identifier = get(identify, 'identifier', v:null)
  if type(identifier) != v:t_dict || !has_key(identifier, 'text')
    return ''
  endif
  return identifier.text
enddef

def HandleDefinitionLocations(locations: list<any>)
  if empty(locations)
    echo 'readseek.vim: no definitions found'
    return
  endif

  if len(locations) == 1
    OpenLocation(locations[0])
    return
  endif

  var project_root = root.Find()
  for location in locations
    location.file = ResolveLocationFile(get(location, 'file', ''), project_root)
  endfor
  quickfix.SetLocations(locations, 'readseek definitions')
enddef

def OpenLocation(location: dict<any>)
  var file = ResolveLocationFile(get(location, 'file', ''), root.Find())
  if empty(file)
    Error('readseek.vim: definition result has no file')
    return
  endif

  execute 'edit ' .. fnameescape(file)
  cursor(get(location, 'line', 1), get(location, 'column', 1))
enddef

def ApplyRename(locations: list<any>, old_name: string, new_name: string, project_root: string)
  var plan_result = BuildRenamePlan(locations, old_name, project_root)
  if !plan_result.ok
    Error(plan_result.error)
    return
  endif

  var changed: dict<bool> = {}
  for file in keys(plan_result.plan)
    var entry = plan_result.plan[file]
    sort(entry.locations, (a, b) => LocationCompare(a, b))

    for location in entry.locations
      var line_text = entry.lines[location.line - 1]
      entry.lines[location.line - 1] = strpart(line_text, 0, location.column - 1) .. new_name .. strpart(line_text, location.column - 1 + len(old_name))
    endfor

    if writefile(entry.lines, file) != 0
      Error($'readseek.vim: failed to write {file}')
      return
    endif
    changed[file] = true
  endfor

  ReloadChangedBuffers(changed)
  echo $'readseek.vim: renamed {old_name} to {new_name} in {plan_result.count} locations'
enddef

def BuildRenamePlan(locations: list<any>, old_name: string, project_root: string): dict<any>
  var plan: dict<any> = {}
  for location in locations
    var file = ResolveLocationFile(get(location, 'file', ''), project_root)
    if empty(file) || !filereadable(file)
      return {ok: false, error: $'readseek.vim: cannot read {file}'}
    endif

    var buffer_number = bufnr(file)
    if buffer_number != -1 && getbufvar(buffer_number, '&modified')
      return {ok: false, error: $'readseek.vim: buffer has unsaved changes: {file}'}
    endif

    if !has_key(plan, file)
      plan[file] = {lines: readfile(file), locations: []}
    endif

    var line_number = get(location, 'line', 0)
    var column = get(location, 'column', 0)
    var lines = plan[file].lines

    if line_number < 1 || line_number > len(lines)
      return {ok: false, error: $'readseek.vim: invalid location {file}:{line_number}:{column}'}
    endif

    var line_text = lines[line_number - 1]
    if column < 1 || strpart(line_text, column - 1, len(old_name)) !=# old_name
      return {ok: false, error: $'readseek.vim: stale location {file}:{line_number}:{column}'}
    endif

    add(plan[file].locations, {line: line_number, column: column})
  endfor

  return {ok: true, plan: plan, count: len(locations)}
enddef

def ReloadChangedBuffers(changed: dict<bool>)
  var save_autoread = &autoread
  set autoread
  try
    for file in keys(changed)
      var buffer_number = bufnr(file)
      if buffer_number != -1
        execute $'checktime {buffer_number}'
      endif
    endfor
  finally
    &autoread = save_autoread
  endtry
enddef

def LocationCompare(left: dict<any>, right: dict<any>): number
  var left_file = get(left, 'file', '')
  var right_file = get(right, 'file', '')
  if left_file !=# right_file
    return left_file ># right_file ? -1 : 1
  endif

  var left_line = get(left, 'line', 0)
  var right_line = get(right, 'line', 0)
  if left_line != right_line
    return right_line - left_line
  endif

  return get(right, 'column', 0) - get(left, 'column', 0)
enddef

def ResolveLocationFile(file: string, project_root: string): string
  if empty(file)
    return ''
  endif

  if file =~# '^/'
    return fnamemodify(file, ':p')
  endif

  if filereadable(file)
    return fnamemodify(file, ':p')
  endif

  return fnamemodify(project_root .. '/' .. substitute(file, '^\./', '', ''), ':p')
enddef

def HoverLines(identify: dict<any>): list<string>
  var lines: list<string> = []
  var identifier = get(identify, 'identifier', v:null)
  if type(identifier) == v:t_dict && has_key(identifier, 'text')
    add(lines, $'Identifier: {identifier.text}')
  endif

  var symbol = get(identify, 'symbol', v:null)
  if type(symbol) == v:t_dict && has_key(symbol, 'name')
    add(lines, $'Symbol: {symbol.name}')
  endif

  if has_key(identify, 'file') && has_key(identify, 'line') && has_key(identify, 'column')
    add(lines, $'{identify.file}:{identify.line}:{identify.column}')
  endif

  return lines
enddef

def ShowHover(lines: list<string>)
  if exists('*popup_create')
    popup_create(lines, {
      pos: 'botleft',
      line: 'cursor+1',
      col: 'cursor',
      padding: [0, 1, 0, 1],
      border: [],
      moved: 'any',
    })
    return
  endif

  echo join(lines, ' | ')
enddef

def Error(message: string)
  echohl ErrorMsg
  echomsg message
  echohl None
enddef
