" ============================================================================
" File:         togglecursor.vim
" Description:  Toggles cursor shape in the terminal
" Maintainer:   John Szakmeister <john@szakmeister.net>
" Version:      0.5.2
" License:      Same license as Vim.
" ============================================================================

if exists('g:loaded_togglecursor') || &compatible || !has('cursorshape')
  finish
endif

" Bail out early if not running under a terminal.
if has("gui_running")
    finish
endif

if !exists("g:togglecursor_disable_neovim")
    let g:togglecursor_disable_neovim = 0
endif

if !exists("g:togglecursor_disable_default_init")
    let g:togglecursor_disable_default_init = 0
endif

if has("nvim")
    " If Neovim support is enabled, then let set the
    " NVIM_TUI_ENABLE_CURSOR_SHAPE for the user.
    if $NVIM_TUI_ENABLE_CURSOR_SHAPE == "" && g:togglecursor_disable_neovim == 0
        let $NVIM_TUI_ENABLE_CURSOR_SHAPE = 1
    endif
    finish
endif

let g:loaded_togglecursor = 1

let s:cursorshape_underline = "\<Esc>]50;CursorShape=2;BlinkingCursorEnabled=0\x7"
let s:cursorshape_line = "\<Esc>]50;CursorShape=1;BlinkingCursorEnabled=0\x7"
let s:cursorshape_block = "\<Esc>]50;CursorShape=0;BlinkingCursorEnabled=0\x7"

let s:cursorshape_blinking_underline = "\<Esc>]50;CursorShape=2;BlinkingCursorEnabled=1\x7"
let s:cursorshape_blinking_line = "\<Esc>]50;CursorShape=1;BlinkingCursorEnabled=1\x7"
let s:cursorshape_blinking_block = "\<Esc>]50;CursorShape=0;BlinkingCursorEnabled=1\x7"

" Note: newer iTerm's support the DECSCUSR extension (same one used in xterm).

let s:xterm_underline = "\<Esc>[4 q"
let s:xterm_line = "\<Esc>[6 q"
let s:xterm_block = "\<Esc>[2 q"

" Not used yet, but don't want to forget them.
let s:xterm_blinking_block = "\<Esc>[0 q"
let s:xterm_blinking_line = "\<Esc>[5 q"
let s:xterm_blinking_underline = "\<Esc>[3 q"

let s:in_screen = $STY !=# ''
let s:in_tmux = $TMUX !=# ''

" Detect whether this version of vim supports changing the replace cursor
" natively.
let s:sr_supported = exists("+t_SR")

let s:supported_terminal = ''

" Check for supported terminals.
if exists("g:togglecursor_force") && g:togglecursor_force != ""
    if count(["xterm", "cursorshape"], g:togglecursor_force) == 0
        echoerr "Invalid value for g:togglecursor_force: " .
                \ g:togglecursor_force
    else
        let s:supported_terminal = g:togglecursor_force
    endif
endif

function! s:GetXtermVersion(version)
    return str2nr(matchstr(a:version, '\v^XTerm\(\zs\d+\ze\)'))
endfunction

if s:supported_terminal == ""
    if &term =~# 'xterm'
        if $TERM_PROGRAM ==# 'iTerm.app' || $ITERM_SESSION_ID !=# ''
                    \ || ($XTERM_VERSION !=# '' && $XTERM_VERSION !=# 'XTerm(256)')
                    " \ || $VTE_VERSION != ""
            " iTerm, xterm, and future VTE based terminals support DESCCUSR.
            " crosh/Secure Shell (ChromeOS) do not support cursor shapes and
            " report Xterm version 256
            let s:supported_terminal = 'xterm'
        elseif $TERM_PROGRAM == "Apple_Terminal" && str2nr($TERM_PROGRAM_VERSION) >= 388
            let s:supported_terminal = 'xterm'
        elseif $TERM == "xterm-kitty"
            let s:supported_terminal = 'xterm'
        elseif $TERM == "rxvt-unicode" || $TERM == "rxvt-unicode-256color"
            let s:supported_terminal = 'xterm'
        elseif str2nr($VTE_VERSION) >= 3900
            let s:supported_terminal = 'xterm'
		elseif $TERM_PROGRAM == "Konsole" || exists("$KONSOLE_DBUS_SESSION")
        " This detection is not perfect.  KONSOLE_DBUS_SESSION seems to show
        " up in the environment despite running under tmux in an ssh
        " session if you have also started a tmux session locally on target
        " box under KDE.

            let s:supported_terminal = 'cursorshape'
        elseif $TERM_PROGRAM ==# 'iTerm2.app' || $ITERM_PROFILE !=# ''
            "iTerm2 has the same cursor shape sequences as Konsole
            let s:supported_terminal = 'cursorshape'
        elseif $TERM_PROGRAM ==# 'gnome-terminal' || $COLORTERM ==# 'gnome-terminal'
                    \ || $VTE_VERSION !=# ''
            "very crude system wide gnome-terminal cursor shape change
            "if has("autocmd")
            "  au InsertEnter * silent execute "!gconftool-2 --type string --set /apps/gnome-terminal/profiles/Default/cursor_shape ibeam"
            "  au InsertLeave * silent execute "!gconftool-2 --type string --set /apps/gnome-terminal/profiles/Default/cursor_shape block"
            "  au VimLeave * silent execute "!gconftool-2 --type string --set /apps/gnome-terminal/profiles/Default/cursor_shape ibeam"
            "endif
            let s:supported_terminal = ''  "TODO: add support for gnome-terminal
        elseif $TERM_PROGRAM ==# 'xfce-terminal'  "TODO: add detection of xfce-terminal
            "very crude system wide xfce-terminal cursor shape change
            "if has("autocmd")
            "  au InsertEnter * silent execute "!sed -i.bak -e 's/TERMINAL_CURSOR_SHAPE_BLOCK/TERMINAL_CURSOR_SHAPE_UNDERLINE/' ~/.config/Terminal/terminalrc"
            "  au InsertLeave * silent execute "!sed -i.bak -e 's/TERMINAL_CURSOR_SHAPE_UNDERLINE/TERMINAL_CURSOR_SHAPE_BLOCK/' ~/.config/Terminal/terminalrc"
            "  au VimLeave * silent execute "!sed -i.bak -e 's/TERMINAL_CURSOR_SHAPE_UNDERLINE/TERMINAL_CURSOR_SHAPE_BLOCK/' ~/.config/Terminal/terminalrc"
            "endif
            let s:supported_terminal = ''  "TODO: add support for xfce-terminal
        elseif $TERM_PROGRAM ==# 'PuTTY'
            "cursor shapes are not supported in PuTTY
            let s:supported_terminal = ''
        else
            let s:supported_terminal = 'xterm'
        endif
    endif
endif

if s:supported_terminal == ''
    " The terminal is not supported, so bail.
    finish
endif


" -------------------------------------------------------------
" Options
" -------------------------------------------------------------

if !exists('g:togglecursor_default')
    let g:togglecursor_default = 'blinking_block'
endif

if !exists('g:togglecursor_insert')
    let g:togglecursor_insert = 'blinking_line'
    " older Xterm versions (older than 282) do not support line shaped cursor (I-beam), only underline
    " cursor shape
    if $XTERM_VERSION != "" && s:GetXtermVersion($XTERM_VERSION) < 282
        let g:togglecursor_insert = 'blinking_underline'
    endif
endif

if !exists('g:togglecursor_replace')
    let g:togglecursor_replace = 'blinking_underline'
endif

if !exists('g:togglecursor_leave')
    if str2nr($VTE_VERSION) >= 3900
        let g:togglecursor_leave = 'blinking_block'
    else
        let g:togglecursor_leave = 'block'
    endif
endif

if !exists('g:togglecursor_disable_screen')
    let g:togglecursor_disable_screen = 0
endif

if !exists('g:togglecursor_disable_tmux')
    let g:togglecursor_disable_tmux = 0
endif

" -------------------------------------------------------------
" Functions
" -------------------------------------------------------------

function! s:ScreenEscape(line)
    " Screen has an escape hatch for talking to the real terminal.  Use it.
    let l:escaped = a:line
    return "\<Esc>P" . l:escaped . "\<Esc>\\"
endfunction

function! s:TmuxEscape(line)
    " Tmux has an escape hatch for talking to the real terminal.  Use it.
    let l:escaped = substitute(a:line, "\<Esc>", "\<Esc>\<Esc>", 'g')
    return "\<Esc>Ptmux;" . l:escaped . "\<Esc>\\"
endfunction

function! s:SupportedTerminal()
    if s:supported_terminal ==# '' || (s:in_tmux && g:togglecursor_disable_tmux) || (s:in_screen && g:togglecursor_disable_screen)
        return 0
    endif

    return 1
endfunction

function! s:GetEscapeCode(shape)
    if !s:SupportedTerminal()
        return ''
    endif

    let l:escape_code = s:{s:supported_terminal}_{a:shape}

    if s:in_screen
        return s:ScreenEscape(l:escape_code)
    endif

    if s:in_tmux
        return s:TmuxEscape(l:escape_code)
    endif

    "Todo: prepend/append original t_SI and t_EI escape sequence

    return l:escape_code
endfunction

function! s:ToggleCursorInit()
    if !s:SupportedTerminal()
        return
    endif

    "Todo: store original t_SI and t_EI escape sequence

    let &t_EI = s:GetEscapeCode(g:togglecursor_default)
    let &t_SI = s:GetEscapeCode(g:togglecursor_insert)
    if s:sr_supported
        let &t_SR = s:GetEscapeCode(g:togglecursor_replace)
    endif
endfunction

function! s:ToggleCursorLeave()
    " One of the last codes emitted to the terminal before exiting is the "out
    " of termcap" sequence.  Tack our escape sequence to change the cursor type
    " onto the beginning of the sequence.
    let &t_te = s:GetEscapeCode(g:togglecursor_leave) . &t_te
endfunction

function! s:ToggleCursorByMode()
    "echomsg "insertmode ".v:insertmode
    if v:insertmode ==# 'r' || v:insertmode ==# 'v'
        let &t_SI = s:GetEscapeCode(g:togglecursor_replace)
    else
        " Default to the insert mode cursor.
        let &t_SI = s:GetEscapeCode(g:togglecursor_insert)
    endif
endfunction

function! s:ToggleCursorModeChange()
    "echomsg "changemode ".v:insertmode
    let l:code = s:GetEscapeCode(g:togglecursor_insert)
    if v:insertmode ==# 'r' || v:insertmode ==# 'v'
        let l:code = s:GetEscapeCode(g:togglecursor_replace)
    endif

    if l:code !=# ''
        "echomsg "l:code=".l:code
        silent execute "!echo -ne '".l:code."'"
        call s:ToggleCursorByMode()
    endif
endfunction

function! ToggleCursorRefresh()
    call s:ToggleCursorInit()
    execute "normal! i\<Esc>l"
    call s:ToggleCursorModeChange()
    execute 'redraw!'
endfunction

" Setting t_ti allows us to get the cursor correct for normal mode when we first
" enter Vim.  Having our escape come first seems to work better with tmux and
" Konsole under Linux.  Allow users to turn this off, since some users of VTE
" 0.40.2-based terminals seem to have issues with the cursor disappearing in the
" certain environments.
if g:togglecursor_disable_default_init == 0
    let &t_ti = s:GetEscapeCode(g:togglecursor_default) . &t_ti
endif

" visual fix for r key (replace letter) in Vim
let g:replace_letter_escape_code = s:GetEscapeCode(g:togglecursor_replace)
nnoremap r :let &t_SI = g:replace_letter_escape_code<CR>:echo ""<CR>r

augroup ToggleCursorStartup
    autocmd!
    autocmd VimEnter * call <SID>ToggleCursorInit()
    autocmd VimLeave * call <SID>ToggleCursorLeave()
    if !s:sr_supported
        autocmd InsertEnter * call <SID>ToggleCursorByMode()
        autocmd InsertChange * call <SID>ToggleCursorModeChange()
    endif
augroup END
