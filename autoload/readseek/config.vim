" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script

export const MinimumVersion = '0.4.29'
const HealthCacheKey = 'readseek_health'

export def LocalBinaryPath(): string
  if has('win32')
    return expand('$APPDATA') .. '\readseek.vim\bin\readseek.exe'
  endif
  return expand('~/.local/share/readseek.vim/bin/readseek')
enddef

export def LocalBinaryDir(): string
  return fnamemodify(LocalBinaryPath(), ':h')
enddef

export def ExecutablePath(): string
  return LocalBinaryPath()
enddef

export def IsExecutableAvailable(): bool
  return filereadable(LocalBinaryPath())
enddef

export def InvalidateHealthCache()
  unlet! g:[HealthCacheKey]
enddef

export def Version(): string
  var output = systemlist(shellescape(ExecutablePath()) .. ' -V')
  if v:shell_error != 0 || empty(output)
    return ''
  endif

  var match = matchstr(output[0], '\v\d+\.\d+\.\d+')
  return match
enddef

export def IsHealthCached(): bool
  var cache = get(g:, HealthCacheKey, v:null)
  return type(cache) == v:t_dict && get(cache, 'path', '') ==# ExecutablePath()
enddef

export def CacheHealth(version: string)
  g:[HealthCacheKey] = {path: ExecutablePath(), version: version}
enddef

export def CheckHealth(): dict<any>
  if IsHealthCached()
    return {ok: true, message: 'readseek.vim: readseek health check already passed'}
  endif

  if !IsExecutableAvailable()
    return {ok: false, message: 'readseek.vim: binary not installed'}
  endif

  var version = Version()
  var path = ExecutablePath()
  CacheHealth(version)
  return {ok: true, message: $'readseek.vim: readseek {version} found at {path}'}
enddef
