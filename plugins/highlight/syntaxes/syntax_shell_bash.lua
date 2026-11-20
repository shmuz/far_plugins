-- Shell / Bash syntax definition for Highlight plugin

Class {
  name = "Shell / Bash";
  filemask = "*.sh,*.bash,*.zsh,*.ksh,*.ash,*.dash,*.ebuild,*.eclass,.bashrc,.bash_profile,.bash_login,.bash_logout,.profile,.zshrc,.zprofile,PKGBUILD,APKBUILD";
  firstline = "bash";

  syntax = {
    bgcolor      = "darkblue";
    bracketmatch = true;
    bracketcolor = 0x1C;

    -- 1. Shebang
    {
      fgcolor = "purple";
      pattern = [=[ ^ \#! .* ]=];
    },

    -- 2. Comments (# preceded by start-of-line, whitespace, or delimiter)
    {
      fgcolor = "gray";
      pattern = [=[ (?: ^ | (?<= [\s;|&(){}\[\]] ) ) \# .* ]=];
    },

    -- 3. Here-strings (placed before heredocs so <<< does not trigger <<)
    {
      fgcolor = "gold";
      pattern = [=[ <<< ]=];
    },

    -- 4. Multi-line heredocs (<<-EOF allows leading tabs on closing delimiter)
    {
      fgcolor   = "yellow";
      pat_open  = [=[ <<- \s* (['"]?) \\? ([A-Za-z_][A-Za-z0-9_]*) \1 ]=];
      pat_close = [=[ ^ \t* %2 $ ]=];
    },
    {
      fgcolor   = "yellow";
      pat_open  = [=[ << \s* (['"]?) \\? ([A-Za-z_][A-Za-z0-9_]*) \1 ]=];
      pat_close = [=[ ^ %2 $ ]=];
    },

    -- 5. Strings (ANSI-C $'...', double-quoted "..." / $"...", single-quoted '...')
    {
      fgcolor   = "yellow";
      pat_open  = [=[ \$' ]=];
      pat_close = [=[ (?: \\. | [^\\'] )* ' ]=];
    },
    {
      fgcolor   = "yellow";
      pat_open  = [=[ \$?" ]=];
      pat_close = [=[ (?: \\. | [^\\"] )* " ]=];
    },
    {
      fgcolor   = "yellow";
      pat_open  = [=[ ' ]=];
      pat_close = [=[ [^']* ' ]=];
    },

    -- 6. Backslash-escaped characters outside quotes
    {
      fgcolor = "gold";
      pattern = [=[ \\ . ]=];
    },

    -- 7. Variables and parameter expansions
    {
      fgcolor = "green";
      pattern = [=[ \$\{ [^{}]+ \} ]=];
    },
    {
      fgcolor = "green";
      pattern = [=[ \$ [?!$\#@*\-_0-9] ]=];
    },
    {
      fgcolor = "green";
      pattern = [=[ \$ [A-Za-z_][A-Za-z0-9_]* ]=];
    },

    -- 8. Variable assignments (VAR=... and VAR+=...)
    {
      fgcolor = "green";
      pattern = [=[ (?: ^ | (?<= [\s;|&(] ) ) [A-Za-z_][A-Za-z0-9_]* (?= \+?= ) ]=];
    },

    -- 9. Function declarations: name()
    {
      fgcolor = "white";
      pattern = [=[ (?: ^ | (?<= [\s;|&{] ) ) [A-Za-z_][A-Za-z0-9_.-]* (?= \s* \( \s* \) ) ]=];
    },

    -- 10. Control flow keywords and [[ ... ]] test brackets
    {
      fgcolor = "white";
      pattern = [=[
        (?: ^ | (?<= [\s;|&(] ) )
        (?: if | then | else | elif | fi | case | esac | for | select
          | while | until | do | done | in | function | time | coproc
          | \[\[ | \]\] )
        (?= $ | [\s;|&)] )
      ]=];
    },

    -- 11. POSIX / Bash builtins
    {
      fgcolor = "blue";
      pattern = [=[
        (?: ^ | (?<= [\s;|&(] ) )
        (?: alias | bg | bind | break | builtin | caller | cd | command
          | compgen | complete | compopt | continue | declare | dirs | disown
          | echo | enable | eval | exec | exit | export | false | fc | fg
          | getopts | hash | help | history | jobs | kill | let | local
          | logout | mapfile | popd | printf | pushd | pwd | read | readarray
          | readonly | return | set | shift | shopt | source | suspend | test
          | times | trap | true | type | typeset | ulimit | umask | unalias
          | unset )
        (?= $ | [\s;|&)] )
      ]=];
    },

    -- 12. Test flags and string/regex comparison operators
    {
      fgcolor = "gold";
      pattern = [=[
        (?<= \s )
        (?: -(?: eq | ne | lt | le | gt | ge | ef | nt | ot
               | [abcdefghkLNOpPrsStuwxzn] )
          | =~ | == | != )
        (?= \s )
      ]=];
    },

    -- 13. Numeric literals (decimal and hex)
    {
      fgcolor = "purple";
      pattern = [=[ (?: ^ | (?<= [\s=:,(\[] ) ) (?: 0[xX][0-9a-fA-F]+ | [0-9]+ ) (?= $ | [\s;|&,)\]] ) ]=];
    },

    -- 14. Redirections, pipes, and grouping operators
    {
      fgcolor = "gold";
      pattern = [=[ >> | >& | <& | <> | >\| | &>> | &> | && | \|\| | ;;& | ;& | ;; | \|& | [|&;<>(){}\[\]] ]=];
    },
  };
}
