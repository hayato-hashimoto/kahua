#!/bin/bash
echo -n "1.1_pre "
if expr "z`svnversion`" : z[0-9][0-9]*\$ > /dev/null
then
echo "svn-r`svnversion`"
else
git_svn_upstream=remotes/trunk
if branch_name=`git symbolic-ref -q HEAD`
then
 branch_name=`expr z\`git symbolic-ref HEAD\` : 'zrefs/heads/\(.*\)'`
else
 branch_name=`** detached HEAD **`
fi
echo "svn-r`git svn find-rev \`git merge-base HEAD $git_svn_upstream\``+git-`git rev-parse --short=8 HEAD` ($branch_name)"
fi
