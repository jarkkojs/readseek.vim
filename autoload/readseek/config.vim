" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script

export const MinimumVersion = '0.3.6'
const HealthCacheKey = 'readseek_health'

export def Executable(): string
  return get(g:, 'readseek_executable', 'readseek')
enddef

export def ExecutablePath(): string
  var executable_name = Executable()
  var executable_path = exepath(executable_name)
  if empty(executable_path)
    return executable_name
  endif
  return executable_path
enddef

export def IsExecutableAvailable(): bool
  return executable(Executable()) == 1
enddef

export def Version(): string
  var output = systemlist([ExecutablePath(), '-V'])
  if v:shell_error != 0 || empty(output)
    return ''
  endif

  var match = matchstr(output[0], '\v\d+\.\d+\.\d+')
  return match
enddef

export def VersionAtLeast(version: string, minimum: string): bool
  if empty(version)
    return false
  endif
  return VersionParts(version) >= VersionParts(minimum)
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
    return {ok: false, message: $'readseek.vim: executable not found: {Executable()}'}
  endif

  var version = Version()
  if !VersionAtLeast(version, MinimumVersion)
    var found = empty(version) ? 'unknown' : version
    return {ok: false, message: $'readseek.vim: readseek {MinimumVersion} or newer required, found {found}'}
  endif

  var path = ExecutablePath()
  CacheHealth(version)
  return {ok: true, message: $'readseek.vim: readseek {version} found at {path}'}
enddef

def VersionParts(version: string): list<number>
  var parts = split(version, '\.')
  return map(parts, (_, part) => str2nr(part))
enddef
