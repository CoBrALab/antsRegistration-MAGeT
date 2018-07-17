#!/usr/bin/env python

from __future__ import division, print_function

import sys

import numpy as np

resscale = (1.0 / float(sys.argv[1]))

# shrinks=""
# blurs=""
# iterations=""
# bins=""

shrinks = []
blurs = []
iterations = []
bins = []

s0 = 1/resscale * 0.5

#Step down in mm subsample space
for shrink in np.logspace(np.log10(16 * resscale), np.log10(resscale), 9):
    if shrink < 1:
      break
    shrinks.append(str(int(np.ceil(shrink))))
    blurs.append(str(np.sqrt((shrink/resscale)**2 - s0**2)))
    iterations.append(str(int(np.around(100 * shrink))))
    bins.append(str(int(np.around((max(32, 256 / max(1, shrink)))))))

blurs.append("0")
shrinks.append("1")
iterations.append("25")
bins.append("256")

#print("x".join(iterations))
#print("x".join(shrinks))
#print("x".join(blurs))
#print("x".join(bins))


print("--transform Rigid[0.5]", end=' ')
print(
    "--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,0.95] ".
    format(bins[2]),
    end=' ')
print("--convergence [{},1e-6,10] ".format("x".join(iterations[0:3])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[0:3])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[0:3])), end=' ')
print("--masks [NULL,NULL]", end=' ')

print("--transform Similarity[0.1]", end=' ')
print(
    "--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,0.95]".format(
        bins[4]),
    end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations[2:5])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[2:5])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[2:5])), end=' ')
print("--masks [NULL,NULL]", end=' ')

print("--transform Affine[0.1]", end=' ')
print(
    "--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,0.95]".format(
        bins[6]),
    end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations[4:7])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[4:7])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[4:7])), end=' ')
print("--masks [${fixedmask},${movingmask}]", end=' ')

print("--transform Affine[0.05]", end=' ')
print(
    "--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,0.95]".format(
        bins[-1]),
    end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations[6:])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[6:])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[6:])), end=' ')
print("--masks [${fixedmask},${movingmask}]", end=' ')
