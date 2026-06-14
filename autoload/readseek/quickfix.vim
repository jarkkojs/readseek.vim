" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script

export def SetLocations(locations: list<any>, title: string)
  var items = ToItems(locations)
  if get(g:, 'readseek_list_type', 'quickfix') ==# 'location'
    setloclist(0, [], 'r', {title: title, items: items})
    lopen
    return
  endif

  setqflist([], 'r', {title: title, items: items})
  copen
enddef

export def ToItems(locations: list<any>): list<dict<any>>
  var items: list<dict<any>> = []
  for location in locations
    add(items, {
      filename: get(location, 'file', ''),
      lnum: get(location, 'line', 1),
      col: get(location, 'column', 1),
      text: get(location, 'text', ''),
    })
  endfor
  return items
enddef
