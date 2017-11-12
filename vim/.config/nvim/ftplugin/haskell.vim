nnoremap <silent> <leader>ht :GhcModType<CR>
nnoremap <silent> <leader>hT :GhcModTypeInsert<CR>
nnoremap <silent> <leader>hc :GhcModTypeClear<CR>

let g:ale_linters.haskell = ['ghc-mod', 'hlint']

if executable("stylish-haskell")
    setlocal formatprg=stylish-haskell
endif

nnoremap <silent> K :call LanguageClient_textDocument_hover()<CR>
nnoremap <silent> gd :call LanguageClient_textDocument_definition()<CR>
nnoremap <silent> <F2> :call LanguageClient_textDocument_rename()<CR>
