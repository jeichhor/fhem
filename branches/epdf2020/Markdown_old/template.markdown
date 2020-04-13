$if(titleblock)$
$titleblock$

$endif$
$for(header-includes)$
$header-includes$

$endfor$
$for(include-before)$
$include-before$

$endfor$
$if(toc)$
$toc$
$if(toc-title)$
# $toc-title$

$endif$

$endif$
$body$
$for(include-after)$

$include-after$
$endfor$
