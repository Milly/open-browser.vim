" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Load Once {{{
if exists('g:loaded_urilib') && g:loaded_urilib
    finish
endif
let g:loaded_urilib = 1
" }}}
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


let g:urilib#version = str2nr(printf('%02d%02d%03d', 0, 0, 6))


function! urilib#load() "{{{
    " dummy function to load this script
endfunction "}}}

function! s:sandbox_call(fn, args, nothrow, NothrowValue) "{{{
    try
        return call(a:fn, a:args)
    catch
        if a:nothrow && s:is_urilib_exception(v:exception)
            return a:NothrowValue
        else
            throw substitute(v:exception, '^Vim([^()]\+):', '', '')
        endif
    endtry
endfunction "}}}

function! urilib#new(uri, ...) "{{{
    let nothrow = a:0 != 0
    let NothrowValue = a:0 ? a:1 : 'unused'
    return s:sandbox_call(
    \   's:new', [a:uri], nothrow, NothrowValue)
endfunction "}}}

function! urilib#new_from_uri_like_string(str, ...) "{{{
    let str = a:str
    if str !~# '^[a-z]\+://'    " no scheme.
        let str = 'http://' . str
    endif

    let nothrow = a:0 != 0
    let NothrowValue = a:0 ? a:1 : 'unused'
    return s:sandbox_call(
    \   's:new', [str], nothrow, NothrowValue)
endfunction "}}}

function! urilib#is_uri(str) "{{{
    let ERROR = []
    return urilib#new(a:str, ERROR) isnot ERROR
endfunction "}}}

function! urilib#like_uri(str) "{{{
    let ERROR = []
    return urilib#new_from_uri_like_string(a:str, ERROR) isnot ERROR
endfunction "}}}

function! urilib#uri_escape(str) "{{{
    let escaped = ''
    for i in range(strlen(a:str))
        if a:str[i] =~# '^[A-Za-z0-9._~"-]$'
            let escaped .= a:str[i]
        else
            let escaped .= printf("%%%02X", char2nr(a:str[i]))
        endif
    endfor
    return escaped
endfunction "}}}

" from Vital.Web.Http.unescape()
function! urilib#uri_unescape(str)
  let ret = a:str
  let ret = substitute(ret, '+', ' ', 'g')
  let ret = substitute(ret, '%\(\x\x\)', '\=nr2char("0x".submatch(1))', 'g')
  return ret
endfunction


" s:uri {{{

function! s:local_func(name) "{{{
    let sid = matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_local_func$')
    return function('<SNR>' . sid . '_' . a:name)
endfunction "}}}



function! s:uri_scheme(...) dict "{{{
    if a:0 && s:is_scheme(a:1)
        let self.__scheme = a:1
    endif
    return self.__scheme
endfunction "}}}

function! s:uri_host(...) dict "{{{
    if a:0 && s:is_host(a:1)
        let self.__host = a:1
    endif
    return self.__host
endfunction "}}}

function! s:uri_port(...) dict "{{{
    if a:0 && s:is_port(a:1)
        let self.__port = a:1
    endif
    return self.__port
endfunction "}}}

function! s:uri_path(...) dict "{{{
    if a:0
        " NOTE: self.__path must not have "/" as prefix.
        let path = substitute(a:1, '^/\+', '', '')
        if s:is_path(path)
            let self.__path = path
        endif
    endif
    return "/" . self.__path
endfunction "}}}

function! s:uri_opaque(...) dict "{{{
    if a:0
        " TODO
        throw 'urilib: uri.opaque(value) does not support yet.'
    endif
    return printf('//%s%s/%s',
    \           self.__host,
    \           (self.__port !=# '' ? ':' . self.__port : ''),
    \           self.__path)
endfunction "}}}

function! s:uri_fragment(...) dict "{{{
    if a:0
        " NOTE: self.__fragment must not have "#" as prefix.
        let fragment = substitute(a:1, '^#', '', '')
        if s:is_fragment(fragment)
            let self.__fragment = fragment
        endif
    endif
    return self.__fragment
endfunction "}}}

function! s:uri_query(...) dict "{{{
    if a:0
        " NOTE: self.__query must not have "?" as prefix.
        let query = substitute(a:1, '^?', '', '')
        if s:is_query(query)
            let self.__query = query
        endif
    endif
    return self.__query
endfunction "}}}

function! s:uri_to_iri() dict "{{{
    " Same as uri.to_string(), but do unescape for self.__path.
    return printf(
    \   '%s://%s%s/%s%s',
    \   self.__scheme,
    \   self.__host,
    \   (self.__port !=# '' ? ':' . self.__port : ''),
    \   urilib#uri_unescape(self.__path),
    \   (self.__fragment != '' ? '#' . self.__fragment : ''),
    \)
endfunction "}}}

function! s:uri_to_string() dict "{{{
    return printf(
    \   '%s://%s%s/%s%s',
    \   self.__scheme,
    \   self.__host,
    \   (self.__port !=# '' ? ':' . self.__port : ''),
    \   self.__path,
    \   (self.__fragment != '' ? '#' . self.__fragment : ''),
    \)
endfunction "}}}


let s:uri = {
\   '__scheme': '',
\   '__host': '',
\   '__port': '',
\   '__path': '',
\   '__query': '',
\   '__fragment': '',
\
\   'scheme': s:local_func('uri_scheme'),
\   'host': s:local_func('uri_host'),
\   'port': s:local_func('uri_port'),
\   'path': s:local_func('uri_path'),
\   'opaque': s:local_func('uri_opaque'),
\   'query': s:local_func('uri_query'),
\   'fragment': s:local_func('uri_fragment'),
\   'to_iri': s:local_func('uri_to_iri'),
\   'to_string': s:local_func('uri_to_string'),
\}
" }}}


function! s:new(str) "{{{
    let [scheme, host, port, path, query, fragment] = s:split_uri(a:str)
    call s:validate_scheme(scheme)
    " TODO: Support punycode
    " let host = ...
    call s:validate_host(host)
    call s:validate_port(port)
    let path = join(map(split(path, '/'), 'urilib#uri_escape(v:val)'), '/')
    call s:validate_path(path)
    call s:validate_query(query)
    call s:validate_fragment(fragment)

    let obj = deepcopy(s:uri)
    call obj.scheme(scheme)
    call obj.host(host)
    call obj.port(port)
    call obj.path(path)
    call obj.query(query)
    call obj.fragment(fragment)
    return obj
endfunction "}}}

function! s:is_urilib_exception(str) "{{{
    return a:str =~# '^uri parse error:'
endfunction "}}}


" Patterns for URI syntax
" cf. http://tools.ietf.org/html/rfc3986#appendix-A
let s:UNRESERVED  = '[[:alpha:][:digit:]._~-]'
let s:PCT_ENCODED = '%[0-9a-fA-F][0-9a-fA-F]'
let s:SUB_DELIMS  = '[!$&''()*+,;=]'


" Parsing URI
function! s:split_uri(str) "{{{
    let rest = a:str

    let [scheme, rest] = s:eat_scheme(rest)
    let [host,   rest] = s:eat_host(rest)
    let [port,   rest] = s:eat_port(rest)

    if rest == ''
        let path = ''
        let query = ''
        let fragment = ''
    else
        let [path    , rest] = s:eat_path(rest)
        let [query   , rest] = s:eat_query(rest)
        let [fragment, rest] = s:eat_fragment(rest)
    endif

    let rest = substitute(rest, '^\s\+', '', '')
    if rest != ''
        throw 'uri parse error: unnecessary string at the end.'
    endif

    return [scheme, host, port, path, query, fragment]
endfunction "}}}
function! s:eat_em(str, pat, ...) "{{{
    let m = matchlist(a:str, a:pat)
    if empty(m)
        if a:0
            return [a:1, a:str]
        else
            throw 'uri parse error: ' . printf("can't parse '%s' with '%s'.", a:str, a:pat)
        endif
    endif
    let [match, want] = m[0:1]
    let rest = strpart(a:str, strlen(match))
    return [want, rest]
endfunction "}}}
function! s:eat_scheme(str) "{{{
    return s:eat_em(a:str, '^\(\w\+\):'.'\C')
endfunction "}}}
function! s:is_scheme(scheme) "{{{
    return a:scheme =~# '^[a-z]\+$'
endfunction "}}}
function! s:eat_host(str) "{{{
    " '\/*' for file:// scheme. it has 3 slashes.
    return s:eat_em(a:str, '^\/\/\(\/*[^:/]\+\)'.'\C')
endfunction "}}}
function! s:is_host(host) "{{{
    return a:host !~# '[^\x00-\xff]'
endfunction "}}}
function! s:eat_port(str) "{{{
    return s:eat_em(a:str, '^:\(\d\+\)'.'\C')
endfunction "}}}
function! s:is_port(port) "{{{
    return a:port =~# '^\d\+$' && 0+a:port ># 0
endfunction "}}}
function! s:eat_path(str) "{{{
    return s:eat_em(a:str, '^\(\/[^#]*\)'.'\C')
endfunction "}}}
function! s:is_path(path) "{{{
    return a:path !~# '[^\x00-\xff]'
endfunction "}}}
function! s:eat_query(str) "{{{
    return s:eat_em(a:str, '^?\(\%('.s:UNRESERVED.'\|'.s:PCT_ENCODED.'\|'.s:SUB_DELIMS.'\|:\|@\)*\)'.'\C')
endfunction "}}}
function! s:is_query(query) "{{{
    return a:query !~# '[^\x00-\xff]'
endfunction "}}}
function! s:eat_fragment(str) "{{{
    return s:eat_em(a:str, '^#\(.*\)'.'\C', '')
endfunction "}}}
function! s:is_fragment(fragment) "{{{
    return a:fragment !~# '[^\x00-\xff]'
endfunction "}}}

" Create s:validate_*() functions.
for [s:where, s:msg] in items({
\   'scheme': 'uri parse error: all characters'
\           . ' in scheme must be [a-z].'
\   'host': 'uri parse error: all characters'
\         . ' in host must be [\x00-\xff].'
\   'port': 'uri parse error: all characters'
\         . ' in port must be digit and the number'
\         . ' is greater than 0.'
\   'path': 'uri parse error: all characters'
\         . ' in path must be [\x00-\xff].'
\   'fragment': 'uri parse error: all characters'
\             . ' in fragment must be [\x00-\xff].'
\}
    execute join([
    \   'function! s:validate_'.where.'(str)',
    \       'if !s:is_'.where.'(a:str)',
    \           'throw '.string(s:msg),
    \       'endif',
    \   'endfunction',
    \], "\n")
endfor
unlet s:where s:msg




" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
