#!/bin/bash

#Packing
#Scinet hates lots of files, and lots of tiny files, we should pack up all the files into a tarball after successful completion
#We can't do this at the end of regular mb.sh because the dependency chain is too long

echo "tar -I pigz -cf output/transforms/atlas-template.tar.gz output/transforms/atlas-template && rm -r output/transforms/atlas-template" > .scripts/${datetime}-mb_pack
echo "tar -I pigz -cf output/transforms/template-subject.tar.gz output/transforms/template-subject && rm -r output/transforms/template-subject" >> .scripts/${datetime}-mb_pack
echo "tar -I pigz -cf output/labels/candidates.tar.gz output/labels/candidates && rm -r output/labels/candidates" >> .scripts/${datetime}-mb_pack
qbatch -j 1 -c 1 .scripts/${datetime}-mb_pack -- "#PBS -l walltime=8:00:00"
