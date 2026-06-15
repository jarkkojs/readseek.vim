# readseek.vim

`readseek.vim` is a source code navigation plugin based on
[`readseek`](https://github.com/jarkkojs/readseek). It's written with
`vim9script`.

The plugin assumes `readseek` is installed and requires `readseek >= 0.3.8`.

Before using the plugin, initialize the readseek map cache:

```sh
readseek init
```

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

Run `:ReadseekCheckHealth` in Vim to verify the executable and version.

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
| `<Plug>(ReadseekDefinition)` | `:ReadseekDefinition`  |
| `<Plug>(ReadseekReferences)` | `:ReadseekReferences`  |
| `<Plug>(ReadseekRename)`     | `:ReadseekRename`      |
| `<Plug>(ReadseekHover)`      | `:ReadseekHover`       |
| `<Plug>(ReadseekSearch)`     | `:ReadseekSearch`      |
| `<Plug>(ReadseekMap)`        | `:ReadseekMap`         |

Define your preferred keys in vimrc:

```vim
nnoremap <silent> gd <Plug>(ReadseekDefinition)
nnoremap <silent> gr <Plug>(ReadseekReferences)
nnoremap <silent> K <Plug>(ReadseekHover)
nnoremap <silent> ,rn <Plug>(ReadseekRename)
nnoremap <silent> ,rs <Plug>(ReadseekSearch)
nnoremap <silent> ,rm <Plug>(ReadseekMap)
```

## Commands

- `:ReadseekCheckHealth` checks executable discovery and `readseek` version.
- `:ReadseekHover` shows identifier context at the cursor.
- `:ReadseekDefinition` jumps to one definition or opens quickfix for multiple.
- `:ReadseekReferences` opens quickfix with references for the cursor identifier.
- `:ReadseekRename` prompts for a new name and updates references found by readseek.
- `:ReadseekMap` maps the current buffer to a symbol outline in the results list.

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
