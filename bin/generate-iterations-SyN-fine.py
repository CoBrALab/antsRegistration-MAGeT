#!/usr/bin/env python

from __future__ import division
from __future__ import print_function
import math
import sys

resscale=(1.0/float(sys.argv[1]))

shrinks=[]
blurs=[]
iterations=[]

#here, scale refers to the resolution processing happens at
#Go from 16 to 2mm
for scale in reversed(range(2,16+2,2)):
    if scale == 0:
        break
    shrinks.append(str(int(scale*resscale)))
    blurs.append(str((scale)/(2.0 * math.sqrt(2.0*math.log(2.0)))))
    iterations.append(str(min(6400,int(25*(scale*resscale)**3))))

#Now do 1mm because sequence above can't do 1
scale=1
shrinks.append(str(max(1,int(scale*resscale))))
blurs.append(str((scale)/(2.0 * math.sqrt(2.0*math.log(2.0))) ))
iterations.append(str(max(25,int(25*(max(1,int(scale*resscale)))**3))))

#For higher resolution data, continue down the chain of subsamples and blurs
#scale here is now a subsample value rather than a resolution
for scale in reversed(range(int(shrinks[-1]))):
    if scale <= 1:
        break
    shrinks.append(str(scale))
    blurs.append(str((scale/resscale)/(2.0 * math.sqrt(2.0*math.log(2.0)))))
    iterations.append(str(int(25*(scale)**3)))

if resscale > 1:
    shrinks.append("1")
    blurs.append(str((1/resscale)/(2.0 * math.sqrt(2.0*math.log(2.0)))))
    iterations.append("25")

#Add one last unblurred step
shrinks.append("1")
blurs.append("0")
iterations.append("25")

print("--transform SyN[0.1]", end=' ')
print("--metric CC[${fixedfile},${movingfile},4]", end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations)), end=' ')
print("--shrink-factors {}".format("x".join(shrinks)), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs)), end=' ')
print("--masks [${fixedmask},${movingmask}]", end=' ')
