#!/usr/bin/env python

from __future__ import division, print_function

import sys

import numpy as np

resscale = (1.0 / float(sys.argv[1]))

shrinks = []
blurs = []
iterations = []

# Based on intrinsic PSF of MRIs, FWHM of pixels are 1/1.2*res (sinc function)
# We assume the base blur resolution is this
s0 = 1 / (resscale * 1.20670912432525704588) * 1 / (2 * np.sqrt(2 * np.log(2)))

for scale in np.logspace(np.log10(8 * resscale), np.log10(resscale), 12):
    if scale < 1:
        break
    shrinks.append(str(int(np.ceil(scale))))
    blurs.append(str(np.sqrt((scale / resscale)**2 - s0**2)))
    iterations.append(str(min(6400, int(np.around(50 * (scale)**3)))))

if resscale > 1:
    scale = resscale
    while scale > 1:
        print(scale)
        shrinks.append(str(int(np.ceil(scale))))
        blurs.append(str(np.sqrt((scale / resscale)**2 - s0**2)))
        iterations.append(str(min(6400, int(np.around(50 * (scale)**3)))))
        scale = scale / 2


shrinks.append("1")
blurs.append("0")
iterations.append("25")

# Compute base bspline level based on size of shrink/scale levels
# print(2**(len(shrinks)-1)*3 / resscale)

# Debug outputs
# print("x".join(iterations))
# print("x".join(shrinks))
# print("x".join(blurs))

print("--convergence [{},1e-6,10]".format("x".join(iterations)), end=' ')
print("--shrink-factors {}".format("x".join(shrinks)), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs)), end=' ')
