#!/usr/bin/env python

from __future__ import division, print_function

import sys

import numpy as np

resscale = (1.0 / float(sys.argv[1]))

shrinks = []
blurs = []
iterations = []
bins = []

# Based on intrinsic PSF of MRIs, FWHM of pixels are 1/1.2*res (sinc function)
# We consider the base "blur" of level 0 to be this resolution
s0 = 1 / (resscale * 1.20670912432525704588) * 1 / (2 * np.sqrt(2 * np.log(2)))

# Step down in mm subsample space from 16 to minimum res
for shrink in np.logspace(np.log10(16 * resscale), 0, 9):
    if shrink < 1:
        break
    shrinks.append(str(int(np.ceil(shrink))))
    blurs.append(str(np.sqrt((shrink / resscale)**2 - s0**2)))
    iterations.append(str(int(np.around(100 * shrink))))
    bins.append(str(int(np.around((max(32, 256 / max(1, shrink)))))))

blurs.append("0")
shrinks.append("1")
iterations.append("50")
bins.append("256")

# Debug outputs
# print("x".join(iterations))
# print("x".join(shrinks))
# print("x".join(blurs))
# print("x".join(bins))

# Start with Rigid Alignment (lsq6)
print("--transform Rigid[0.5]", end=' ')
print(
    "--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,0.95] ".
    format(bins[2]),
    end=' ')
print("--convergence [{},1e-6,10] ".format("x".join(iterations[0:3])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[0:3])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[0:3])), end=' ')
print("--masks [NULL,NULL]", end=' ')

# Follow up with Similarity (lsq7)
print("--transform Similarity[0.1]", end=' ')
print(
    "--metric Mattes[${{fixedfile}},${{movingfile}},1,{},Regular,0.95]".format(
        bins[4]),
    end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations[2:5])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[2:5])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[2:5])), end=' ')
print("--masks [NULL,NULL]", end=' ')

# Here I'd like a lsq9-like alignment, but nothing exists in ITK right now

# Affine alignment (lsq12) with masks, GC is much more sensitive with a mask
print("--transform Affine[0.1]", end=' ')
print(
    "--metric GC[${{fixedfile}},${{movingfile}},1,{},Regular,0.95]".format(
        bins[6]),
    end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations[4:7])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[4:7])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[4:7])), end=' ')
print("--masks [${fixedmask},${movingmask}]", end=' ')

# Finer affine alignment with masks (lsq12)
print("--transform Affine[0.05]", end=' ')
print(
    "--metric GC[${{fixedfile}},${{movingfile}},1,{},Regular,1]".format(
        bins[-1]),
    end=' ')
print("--convergence [{},1e-7,10]".format("x".join(iterations[6:])), end=' ')
print("--shrink-factors {}".format("x".join(shrinks[6:])), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs[6:])), end=' ')
print("--masks [${fixedmask},${movingmask}]", end=' ')
