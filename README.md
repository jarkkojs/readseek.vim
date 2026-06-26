# readseek.vim

`readseek.vim` is a source code navigation plugin based on
[`readseek`](https://github.com/jarkkojs/readseek). It's written with
`vim9script`.

The plugin assumes `readseek` is installed and requires `readseek >= 0.4.15`.

Before using the plugin, initialize the readseek map cache, either from a shell:

```sh
readseek init
```

or from Vim with `:ReadSeekInit`, which initializes the cache for the current
project root.

NOTE: this is still highly experimental plugin and somewhat unfinished.

## Installation

### vim-plug

```vim
Plug 'jarkkojs/readseek.vim'
```

## Vim's built-in packaging

```sh
git clone https://github.com/jarkkojs/readseek.vim \
  ~/.vim/pack/plugins/start/readseek.vim
vim -u NONE -c 'helptags ~/.vim/pack/plugins/start/readseek.vim/doc' -c q
```

Run `:ReadSeekCheckHealth` in Vim to verify the executable and version.

## Configuration

```vim
" Executable name or absolute path.
let g:readseek_executable = 'readseek'

" Root marker search order. The nearest directory containing one is used.
let g:readseek_root_markers = ['.git']

" Use quickfix or location-list output. Defaults to 'quickfix'.
let g:readseek_list_type = 'quickfix'
```

Available `<Plug>` mappings:

| Mapping                      | Command                |
|------------------------------|------------------------|
| `<Plug>(ReadSeekDefinition)` | `:ReadSeekDefinition`  |
| `<Plug>(ReadSeekReferences)` | `:ReadSeekReferences`  |
| `<Plug>(ReadSeekRename)`     | `:ReadSeekRename`      |
| `<Plug>(ReadSeekHover)`      | `:ReadSeekHover`       |
| `<Plug>(ReadSeekSearch)`     | `:ReadSeekSearch`      |
| `<Plug>(ReadSeekMap)`        | `:ReadSeekMap`         |
| `<Plug>(ReadSeekInit)`       | `:ReadSeekInit`        |

Define your preferred keys in vimrc:

```vim
nnoremap <silent> gd <Plug>(ReadSeekDefinition)
nnoremap <silent> gr <Plug>(ReadSeekReferences)
nnoremap <silent> K <Plug>(ReadSeekHover)
nnoremap <silent> ,rn <Plug>(ReadSeekRename)
nnoremap <silent> ,rs <Plug>(ReadSeekSearch)
nnoremap <silent> ,rm <Plug>(ReadSeekMap)
```

## Commands

- `:ReadSeekCheckHealth` checks executable discovery and `readseek` version.
- `:ReadSeekHover` shows identifier context at the cursor.
- `:ReadSeekDefinition` jumps to one definition or opens quickfix for multiple.
- `:ReadSeekReferences` opens quickfix with references for the cursor identifier.
- `:ReadSeekRename` prompts for a new name and applies a binding-accurate rename
  to the current (saved) file via `readseek rename --apply`.
- `:ReadSeekMap` maps the current buffer to a symbol outline in the results list.
- `:ReadSeekInit` initializes the `readseek` cache for the current project root.

## Tests

Run the lightweight Vim script test suite with:

```sh
vim -Nu NONE -n -i NONE -es -S test/readseek.vim
```

See `:help readseek` for detailed behavior and troubleshooting.

## License

`readseek.vim` is licensed under `MIT`. See [LICENSE](LICENSE) for more
information.

The upstream `readseek` package is licensed under `Apache-2.0 AND
LGPL-2.1-or-later`.
