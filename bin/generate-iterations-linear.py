#!/usr/bin/env python

from __future__ import division
from __future__ import print_function
import math
import sys

resscale=(1.0/float(sys.argv[1]))

#shrinks=""
#blurs=""
#iterations=""
#bins=""

shrinks=[]
blurs=[]
iterations=[]
bins=[]

#Starting at 16mm scale
scale=16

#Step down from 16mm to 1mm in blurs, calculate subsample based on input resolution
while scale > 0.5:
    shrinks.append(str(max(1,int(scale*resscale))))
    blurs.append(str((scale)/(2.0 * math.sqrt(2.0*math.log(2.0)))))
    iterations.append(str(min(6400,int(100*max(1,scale*resscale)**3))))
    bins.append(str(int(max(32,256/max(1,scale)))))
    scale=scale/2

#For higher resolution data, continue down the chain of subsamples and blurs
#scale here is now a subsample value rather than a resolution
for scale in reversed(range(int(shrinks[-1]))):
    if scale <= 1:
      break
    shrinks.append(str(scale))
    blurs.append(str((scale/resscale)/(2.0 * math.sqrt(2.0*math.log(2.0)))))
    iterations.append(str(int(100*(scale)**3)))


blurs.append("0")
shrinks.append("1")
iterations.append("100")
bins.append("256")

print("--transform Rigid[0.5]", end=' ')
print("--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,1] ".format(bins[0]), end=' ')
print("--convergence [{},1e-6,10] ".format("x".join(iterations[:3])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[:3])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[:3])), end=' ')
print("--masks [NULL,NULL]", end=' ')

print("--transform Similarity[0.1]", end=' ')
print("--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,1]".format(bins[2]), end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations[1:4])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[1:4])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[1:4])), end=' ')
print("--masks [NULL,NULL]", end=' ')

print("--transform Affine[0.1]")
print("--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,1]".format(bins[3]), end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations[2:5])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[2:5])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[2:5])), end=' ')
print("--masks [${fixedmask},${movingmask}]", end=' ')

print("--transform Affine[0.05]", end=' ')
print("--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,1]".format(bins[4]), end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations[3:])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[3:])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[3:])), end=' ')
print("--masks [${fixedmask},${movingmask}]", end=' ')
