" SPDX-License-Identifier: MIT
" Copyright (c) 2026 Jarkko Sakkinen

vim9script

import autoload 'readseek/config.vim'

const GithubRepo = 'jarkkojs/readseek'

export def Install(Callback: func)
  var platform = Platform()
  if empty(platform)
    Callback({ok: false, error: 'unsupported platform'})
    return
  endif

  var version = config.MinimumVersion
  var asset = $'readseek-{version}-{platform}.tar.gz'
  var url = $'https://github.com/{GithubRepo}/releases/download/{version}/{asset}'
  var dest_dir = config.LocalBinaryDir()

  if !isdirectory(dest_dir)
    mkdir(dest_dir, 'p')
  endif

  var tmpfile = tempname() .. '.tar.gz'

  Download(url, tmpfile, (ok: bool, err: string) => {
    if !ok
      delete(tmpfile)
      Callback({ok: false, error: $'download failed: {err}'})
      return
    endif

    var tmpdir = tempname()
    mkdir(tmpdir, 'p')
    var extract_out = system($'tar -xzf {shellescape(tmpfile)} -C {shellescape(tmpdir)}')
    delete(tmpfile)

    if v:shell_error != 0
      Callback({ok: false, error: $'extraction failed: {trim(extract_out)}'})
      return
    endif

    var binary_name = has('win32') ? 'readseek.exe' : 'readseek'
    var found = trim(system($'find {shellescape(tmpdir)} -name {shellescape(binary_name)} -type f'))

    if empty(found) || v:shell_error != 0
      system($'rm -rf {shellescape(tmpdir)}')
      Callback({ok: false, error: 'binary not found in archive'})
      return
    endif

    var dest = config.LocalBinaryPath()
    system($'mv {shellescape(found)} {shellescape(dest)}')
    system($'rm -rf {shellescape(tmpdir)}')

    if v:shell_error != 0
      Callback({ok: false, error: 'failed to move binary to destination'})
      return
    endif

    if !has('win32')
      system($'chmod +x {shellescape(dest)}')
    endif

    config.InvalidateHealthCache()
    Callback({ok: true, path: dest, version: version})
  })
enddef

def Platform(): string
  if has('mac')
    return 'darwin-arm64'
  elseif has('win32')
    return 'win32-x64'
  elseif has('unix')
    return 'linux-x64-musl'
  endif
  return ''
enddef

def Download(url: string, dest: string, Callback: func)
  var cmd: list<string>
  if executable('curl')
    cmd = ['curl', '-fsSL', '-o', dest, url]
  elseif executable('wget')
    cmd = ['wget', '-q', '-O', dest, url]
  else
    Callback(false, 'curl or wget required for installation')
    return
  endif

  var stderr_lines: list<string> = []

  def OnStderr(channel: channel, message: string)
    add(stderr_lines, message)
  enddef

  def OnExit(job_obj: job, status: number)
    Callback(status == 0, join(stderr_lines, "\n"))
  enddef

  job_start(cmd, {
    err_cb: OnStderr,
    exit_cb: OnExit,
    err_mode: 'nl',
  })
enddef
