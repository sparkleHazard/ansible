"--------------------
"General Settings
"--------------------

set background=dark
syntax enable
set expandtab
set shiftwidth=4
set tabstop=4
set hidden
set relativenumber
set number
set termguicolors
set undofile
set title
set ignorecase
set smartcase
set incsearch
set wildmode=longest:full,full
"set nowrap
set wrap
set list
set listchars=tab:➤\ ,trail:◆
set mouse=a
set scrolloff=8
set nojoinspaces
set splitright
set splitbelow
set clipboard=unnamedplus
set confirm
set exrc
set backup
set backupdir=~/.local/share/vim/backup//
set nobackup
set nowritebackup
set updatetime=300
set signcolumn=yes
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

"----------
"Key Maps
"----------

let mapleader = "\<SPACE>"

nmap <leader>ve :edit ~/.vimrc<cr>
nmap <leader>vr :source ~/.vimrc<cr>

nnoremap <leader>h :History<CR>
nnoremap <leader>F :Files ./<CR>
nnoremap <leader>g :Rg<CR>

" Navigating buffers
nnoremap <leader>bb :Buffers<CR>
nnoremap <leader>bn :bn<CR>
nnoremap <leader>bp :bp<CR>
nnoremap <leader>bd :bd<CR>

" Navigating tabs
nnoremap <leader>tt :tabnew<CR>
nnoremap <leader>tn :tabnext<CR>
nnoremap <leader>tp :tabprevious<CR>

" Changing window size
"nnoremap <C-j> :5winc + <CR>
"nnoremap <C-k> :5winc - <CR>
"nnoremap <C-h> :5winc > <CR>
"nnoremap <C-l> :5winc < <CR>

"----------
"Coc-Explorer
"----------

let g:coc_explorer_global_presets = {
\   '.vim': {
\     'root-uri': '~/.vim',
\   },
\   'cocConfig': {
\      'root-uri': '~/.config/coc',
\   },
\   'tab': {
\     'position': 'tab',
\     'quit-on-open': v:true,
\   },
\   'tab:$': {
\     'position': 'tab:$',
\     'quit-on-open': v:true,
\   },
\   'floating': {
\     'position': 'floating',
\     'open-action-strategy': 'sourceWindow',
\   },
\   'floatingTop': {
\     'position': 'floating',
\     'floating-position': 'center-top',
\     'open-action-strategy': 'sourceWindow',
\   },
\   'floatingLeftside': {
\     'position': 'floating',
\     'floating-position': 'left-center',
\     'floating-width': 50,
\     'open-action-strategy': 'sourceWindow',
\   },
\   'floatingRightside': {
\     'position': 'floating',
\     'floating-position': 'right-center',
\     'floating-width': 50,
\     'open-action-strategy': 'sourceWindow',
\   },
\   'simplify': {
\     'file-child-template': '[selection | clip | 1] [indent][icon | 1] [filename omitCenter 1]'
\   },
\   'buffer': {
\     'sources': [{'name': 'buffer', 'expand': v:true}]
\   },
\ }

" Use preset argument to open it
noremap <leader>n :CocCommand explorer --preset tab<CR>
nmap <space>nd <Cmd>CocCommand explorer --preset .vim<CR>
nmap <space>nf <Cmd>CocCommand explorer --preset floating<CR>
nmap <space>nc <Cmd>CocCommand explorer --preset cocConfig<CR>
nmap <space>nb <Cmd>CocCommand explorer --preset buffer<CR>

" List all presets
nmap <space>nl <Cmd>CocList explPresets<CR>

"----------
"AutoCommands
"----------

" Make sure .aliases, .bash_aliases and similar files get syntax highlighting.
autocmd BufNewFile,BufRead .*aliases set ft=sh
autocmd BufNewFile,BufRead *.rc set ft=sh
autocmd BufNewFile,BufRead *.*sh set ft=sh

" Make sure all types of requirements.txt files get syntax hightlighting.
autocmd BufNewFile,BufRead requirements*.txt set ft=python

augroup run_file
    autocmd!
    autocmd BufEnter *.sh let @g=":w\<CR>:sp | terminal bash %\<CR>:wincmd k\<CR>:q\<CR>:wincmd j\<CR>"
    autocmd BufEnter *.py let @g=":w\<CR>:sp | terminal python3 %\<CR>:wincmd k\<CR>:q\<CR>:wincmd j\<CR>"
    autocmd BufEnter *.java let @g=":w\<CR>:sp | terminal bash /home/swaddena/java-dev/java-vim-run.sh %:p\<CR> | :wincmd k\<CR>:q\<CR>:wincmd j\<CR>"
augroup end

function! AuCocExplorerAutoOpen()
    let l:use_floating = 0

    " Auto-open explorer when there's no file to show.
    if @% == '' || @% == '.'
        if l:use_floating
            exe ':CocCommand explorer --position floating'
        else
            autocmd User CocExplorerOpenPost ++once exe ':only'
            exe ':CocCommand explorer'
        endif
    endif
endfunction
autocmd User CocNvimInit call AuCocExplorerAutoOpen()

"augroup CocExplorer
"    au!
"    au VimEnter * sil! au! CocCommand explorer *
"    au BufEnter * if s:isdir(expand('%')) | bd | :CocCommand explorer | endif
"augroup END
"
"fu! s:isdir(dir) abort
"    return !empty(a:dir) && (isdirectory(a:dir) ||
"                \ (!empty($SYSTEMDRIVE) && isdirectory('/'.tolower($SYSTEMDRIVE[0]).a:dir)))
"endfu

"----------
"Plugins
"----------

" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif
" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

call plug#begin()

Plug 'edkolev/tmuxline.vim'
Plug 'tpope/vim-commentary'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'dracula/vim',{'as':'dracula'}
Plug 'ryanoasis/vim-devicons'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/fzf'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'ojroques/vim-oscyank', {'branch': 'main'}
Plug 'puremourning/vimspector'
Plug 'sagi-z/vimspectorpy', { 'do': { -> vimspectorpy#update() } }
Plug 'airblade/vim-gitgutter'
Plug 'voldikss/vim-floaterm'
Plug 'honza/vim-snippets'
Plug 'jiangmiao/auto-pairs'

call plug#end()

" Floaterm navigation
nnoremap <leader>tt :FloatermNew<cr>

" tmuxline
let g:airline_detect_modified = 1
let g:airline_detect_paste = 1
let g:airline_detect_crypt = 1
let g:airline_detect_spell = 1
let g:airline_detect_spelllang = 1
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tmuxline#enabled = 0

colorscheme dracula

let g:airline_theme='dracula'
let g:tmuxline_preset = {
      \'a'    : '#S',
      \'c'    : ['#(whoami)', '#{tmux_mode_indicator}'],
      \'win'  : ['#I', '#W'],
      \'cwin' : ['#I', '#W', '#F'],
      \'x'    : '#(date)',
      \'y'    : ['%R', '%a', '%Y'],
      \'z'    : '#H'}

let g:vimspector_enable_mappings = 'VISUAL_STUDIO'
let g:vimspector_base_dir='/local/home/swaddena/.vim/plugged/vimspector'

" ---------- COC TEMPLATE CONFIG ---------- "
" Some servers have issues with backup files, see #649.

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.

" Use tab for trigger completion with characters ahead and navigate.
" NOTE: There's always complete item selected by default, you may want to enable
" no select by `"suggest.noselect": true` in your configuration file.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice.
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window.
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code.
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

augroup mygroup
autocmd!
" Setup formatexpr specified filetype(s).
autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
" Update signature help on jump placeholder.
autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Applying codeAction to the selected region.
" Example: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap keys for applying codeAction to the current buffer.
nmap <leader>ac  <Plug>(coc-codeaction)
" Apply AutoFix to problem on the current line.
nmap <leader>qf  <Plug>(coc-fix-current)

" Run the Code Lens action on the current line.
nmap <leader>cl  <Plug>(coc-codelens-action)

" Map function and class text objects
" NOTE: Requires 'textDocument.documentSymbol' support from the language server.
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Remap <C-f> and <C-b> for scroll float windows/popups.
if has('nvim-0.4.0') || has('patch-8.2.0750')
nnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
nnoremap <silent><nowait><expr> <C-F> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
inoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
inoremap <silent><nowait><expr> <C-F> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
vnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
vnoremap <silent><nowait><expr> <C-F> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
endif

" Use CTRL-S for selections ranges.
" Requires 'textDocument/selectionRange' support of language server.
nmap <silent> <C-s> <Plug>(coc-range-select)
xmap <silent> <C-s> <Plug>(coc-range-select)

" Add `:Format` command to format current buffer.
command! -nargs=0 Format :call CocActionAsync('format')

" Add `:Fold` command to fold current buffer.
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" Add `:OR` command for organize imports of the current buffer.
command! -nargs=0 OR   :call     CocActionAsync('runCommand', 'editor.action.organizeImport')

" Add (Neo)Vim's native statusline support.
" NOTE: Please see `:h coc-status` for integrations with external plugins that
" provide custom statusline: lightline.vim, vim-airline.

" Mappings for CoCList
" Show all diagnostics.
nnoremap <silent><nowait> <space>A  :<C-u>CocList diagnostics<cr>
" Manage extensions.
nnoremap <silent><nowait> <space>e  :<C-u>CocList extensions<cr>
" Show commands.
nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document.
nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols.
nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list.
nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>
