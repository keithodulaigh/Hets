#!/bin/bash

createXUpdate ()
{
f=`dirname $1`/`basename $1 .het`
hets -v2 -o xml $f
mv $f.xml $f.xh
hets -v2 -A -o xml $f
mv $f.xml $f.xhi
cp $1 $1.bak
diff -u $1 $2 > patch
patch $1 patch
hets -v2 -o xml $f
mv $f.xml $f.new.xh
cp $1.bak $1
dir=`pwd`
b2=`basename $2 .het`
pushd $HETS_GMOC
rm -f tmp/*.xupdate
bin/gmoc -c Configuration.xml -itype file moc \
  $dir/$f.xh $dir/$f.xhi $dir/$f.new.xh
mv tmp/*.xupdate $dir/$b2.xupdate
popd
}

propagateDiff ()
{
diff $1 $3 > patch
patch $2 patch
}

createUpdates ()
{
for i in Spec.het
do
   for j in Add Remove Modify
   do
       for k in Symbol Axiom Theorem
       do createXUpdate $i $j$k$i
       done
   done
done
}

callHets ()
{
for i in *.xupdate
do
hets -v2 -U $i Spec.het
done
}