" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script

import autoload 'readseek/buffer.vim'
import autoload 'readseek/config.vim'
import autoload 'readseek/job.vim'
import autoload 'readseek/quickfix.vim'
import autoload 'readseek/repo.vim'
import autoload 'readseek/root.vim'

export def CheckHealth()
  var result = config.CheckHealth()

  var lines: list<string> = []

  var exec_ok = config.IsExecutableAvailable()
  var exec_path = config.ExecutablePath()
  if exec_ok
    add(lines, $'✓ {exec_path}')
  else
    add(lines, $'✗ {config.Executable()} (not found)')
  endif

  var version = config.Version()
  var version_ok = config.VersionAtLeast(version, config.MinimumVersion)
  if version_ok
    add(lines, $'✓ readseek {version}')
  else
    add(lines, $'✗ readseek {empty(version) ? "unknown" : version} (need >= {config.MinimumVersion})')
  endif

  var readseek_dir = repo.FindReadseekDir()
  if !empty(readseek_dir)
    add(lines, $'✓ .readseek/ at {readseek_dir}')
  else
    add(lines, '✗ .readseek/ not found (run :ReadseekInit)')
  endif

  var project_root = root.Find()
  add(lines, $'  project root: {project_root}')

  if exists('*popup_create')
    popup_create(lines, {
      pos: 'center',
      padding: [1, 2, 1, 2],
      border: [1, 1, 1, 1],
      borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
      borderhighlight: ['ReadseekBorder'],
      title: ' readseek health ',
      scrollbar: 0,
      wrap: false,
      close: 'click',
      moved: 'any',
    })
    return
  endif

  for line in lines
    echo line
  endfor
enddef

export def Hover()
  Identify((result: dict<any>) => {
    if !result.ok
      Notify(get(result, 'error', 'readseek identify failed'), 'error')
      return
    endif

    var lines = HoverLines(result.json)
    if empty(lines)
      Notify('no identifier at cursor', 'info')
      return
    endif

    ShowHover(lines)
  })
enddef

export def Definition()
  var project_root = root.Find()
  Status('finding definition...')
  Identify((identify_result: dict<any>) => {
    if !identify_result.ok
      Notify(get(identify_result, 'error', 'readseek identify failed'), 'error')
      return
    endif

    job.Run(['def', '--stdin', '--format', 'plain', project_root], identify_result.stdout, (definition_result: dict<any>) => {
      if !definition_result.ok
        Notify(get(definition_result, 'error', 'readseek definition failed'), 'error')
        return
      endif
      HandleDefinitionLocations(get(definition_result.json, 'locations', []), project_root)
    })
  })
enddef

export def References()
  Identify((identify_result: dict<any>) => {
    if !identify_result.ok
      Notify(get(identify_result, 'error', 'readseek identify failed'), 'error')
      return
    endif

    var identifier_text = IdentifierText(identify_result.json)
    if empty(identifier_text)
      Notify('no identifier at cursor', 'info')
      return
    endif

    var project_root = root.Find()
    Status($'finding references for {identifier_text}...')
    job.Run(['refs', '--format', 'plain', project_root, identifier_text], '', (references_result: dict<any>) => {
      if !references_result.ok
        Notify(get(references_result, 'error', 'readseek references failed'), 'error')
        return
      endif

      var locations = get(references_result.json, 'locations', [])
      if empty(locations)
        Notify($'no references found for {identifier_text}', 'info')
        return
      endif

      Status($'{len(locations)} {Plural(len(locations), 'reference')} found for {identifier_text}')
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
      Notify(get(identify_result, 'error', 'readseek identify failed'), 'error')
      return
    endif

    var old_name = IdentifierText(identify_result.json)
    if empty(old_name)
      Notify('no identifier at cursor', 'info')
      return
    endif

    var new_name = input($'Rename {old_name} to: ', old_name)
    if empty(new_name) || new_name ==# old_name
      return
    endif

    var project_root = root.Find()
    Status($'finding references for {old_name}...')
    job.Run(['refs', '--format', 'plain', project_root, old_name], '', (references_result: dict<any>) => {
      if !references_result.ok
        Notify(get(references_result, 'error', 'readseek references failed'), 'error')
        return
      endif

      var locations = get(references_result.json, 'locations', [])
      if empty(locations)
        Notify($'no references found for {old_name}', 'info')
        return
      endif

      Status($'{len(locations)} {Plural(len(locations), 'reference')} found for {old_name}')
      ApplyRename(locations, old_name, new_name, project_root)
    })
  })
enddef

export def Init()
  var dir = getcwd()
  var proceed = confirm($'Create .readseek/ in {dir} ?', "&Yes\n&No", 1)
  if proceed != 1
    return
  endif

  Notify('initializing .readseek/...', 'info')
  job.Run(['init', dir], '', (result: dict<any>) => {
    if result.ok
      Notify('.readseek/ initialized', 'ok')
    else
      var msg = get(result, 'stderr', 'init failed')
      Notify(empty(msg) ? 'init failed' : msg, 'error')
    endif
  })
enddef

export def Search()
  var pattern = input('readseek pattern: ')
  if empty(pattern)
    return
  endif

  var project_root = root.Find()
  Status($'searching for {pattern}...')

  job.Run(['search', project_root, pattern], '', (result: dict<any>) => {
    if !result.ok
      var msg = get(result, 'stderr', 'search failed')
      Notify(empty(msg) ? 'search failed' : msg, 'error')
      return
    endif

    var files = get(result.json, 'files', [])
    var locations: list<any> = []
    for file_entry in files
      var file = ResolveLocationFile(get(file_entry, 'file', ''), project_root)
      var matches = get(file_entry, 'matches', [])
      for match_entry in matches
        add(locations, {
          file: file,
          line: get(match_entry, 'line', 1),
          column: get(match_entry, 'column', 1),
          text: get(match_entry, 'text', ''),
        })
      endfor
    endfor

    if empty(locations)
      Notify($'no matches for {pattern}', 'info')
      return
    endif

    Notify($'{len(locations)} {Plural(len(locations), "match")} for {pattern}', 'ok')
    quickfix.SetLocations(locations, $'readseek search: {pattern}')
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

def HandleDefinitionLocations(locations: list<any>, project_root: string)
  if empty(locations)
    Notify('no definitions found', 'info')
    return
  endif

  if len(locations) == 1
    Status('1 definition found')
    OpenLocation(locations[0], project_root)
    return
  endif

  Status($'{len(locations)} definitions found')
  for location in locations
    location.file = ResolveLocationFile(get(location, 'file', ''), project_root)
  endfor
  quickfix.SetLocations(locations, 'readseek definitions')
enddef

def OpenLocation(location: dict<any>, project_root: string)
  var file = ResolveLocationFile(get(location, 'file', ''), project_root)
  if empty(file)
    Notify('definition result has no file', 'error')
    return
  endif

  execute 'edit ' .. fnameescape(file)
  cursor(get(location, 'line', 1), get(location, 'column', 1))
enddef

def ApplyRename(locations: list<any>, old_name: string, new_name: string, project_root: string)
  var plan_result = BuildRenamePlan(locations, old_name, project_root)
  if !plan_result.ok
    Notify(plan_result.error, 'error')
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
      Notify($'failed to write {file}', 'error')
      return
    endif
    changed[file] = true
  endfor

  ReloadChangedBuffers(changed)
  Notify($'renamed {old_name} to {new_name} in {plan_result.count} locations', 'ok')
enddef

def BuildRenamePlan(locations: list<any>, old_name: string, project_root: string): dict<any>
  var plan: dict<any> = {}
  for location in locations
    var file = ResolveLocationFile(get(location, 'file', ''), project_root)
    if empty(file) || !filereadable(file)
      return {ok: false, error: $'cannot read {file}'}
    endif

    var buffer_number = bufnr(file)
    if buffer_number != -1 && getbufvar(buffer_number, '&modified')
      return {ok: false, error: $'buffer has unsaved changes: {file}'}
    endif

    if !has_key(plan, file)
      plan[file] = {lines: readfile(file), locations: []}
    endif

    var line_number = get(location, 'line', 0)
    var column = get(location, 'column', 0)
    var lines = plan[file].lines

    if line_number < 1 || line_number > len(lines)
      return {ok: false, error: $'invalid location {file}:{line_number}:{column}'}
    endif

    var line_text = lines[line_number - 1]
    if column < 1 || strpart(line_text, column - 1, len(old_name)) !=# old_name
      return {ok: false, error: $'stale location {file}:{line_number}:{column}'}
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

  return fnamemodify(project_root .. '/' .. substitute(file, '^\./', '', ''), ':p')
enddef

export def HoverLines(identify: dict<any>): list<string>
  var lines: list<string> = []
  var identifier = get(identify, 'identifier', v:null)
  if type(identifier) == v:t_dict && has_key(identifier, 'text')
    add(lines, $'identifier: {identifier.text}')
  endif

  var symbol = get(identify, 'symbol', v:null)
  if type(symbol) == v:t_dict && has_key(symbol, 'name')
    add(lines, $'symbol: {symbol.name}')
    if has_key(symbol, 'kind')
      add(lines, $'kind: {symbol.kind}')
    endif
  endif

  if has_key(identify, 'file') && has_key(identify, 'line') && has_key(identify, 'column')
    add(lines, $'location: {identify.file}:{identify.line}:{identify.column}')
  endif

  return lines
enddef

def ShowHover(lines: list<string>)
  if exists('*popup_create')
    var title = ' readseek '
    if !empty(lines)
      title = $' {lines[0]} '
    endif

    popup_create(lines, {
      pos: 'botleft',
      line: 'cursor+1',
      col: 'cursor',
      padding: [0, 1, 0, 1],
      border: [1, 1, 1, 1],
      borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
      borderhighlight: ['ReadseekBorder'],
      title: title,
      moved: 'any',
      scrollbar: 1,
      wrap: false,
    })
    return
  endif

  echo join(lines, ' | ')
enddef

def Notify(message: string, level: string = 'info')
  if !exists('*popup_notification')
    if level == 'error'
      echohl ErrorMsg
    elseif level == 'warn'
      echohl WarningMsg
    endif
    echomsg $'readseek.vim: {message}'
    echohl None
    return
  endif

  var highlight = 'ReadseekInfo'
  if level == 'error'
    highlight = 'ReadseekError'
  elseif level == 'warn'
    highlight = 'ReadseekWarn'
  elseif level == 'ok'
    highlight = 'ReadseekOk'
  endif

  popup_notification($' readseek.vim: {message} ', {
    highlight: highlight,
    time: 4000,
    pos: 'topright',
    line: 1,
    col: 1,
  })
enddef

def Status(message: string)
  echohl ModeMsg
  echomsg 'readseek.vim: ' .. message
  echohl None
enddef

def Plural(count: number, word: string): string
  return count == 1 ? word : word .. 's'
enddef
