" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script

export def FindReadseekDir(): string
  var dir = getcwd()

  while !empty(dir)
    if isdirectory(dir .. '/.readseek')
      return dir
    endif

    var parent = fnamemodify(dir, ':h')
    if parent == dir
      break
    endif
    dir = parent
  endwhile

  return ''
enddef

export def HasReadseek(): bool
  return !empty(FindReadseekDir())
enddef
