#!/usr/bin/env python

from __future__ import division, print_function

import sys

import numpy as np

resscale = (1.0 / float(sys.argv[1]))
#steps = int(sys.argv[2])

shrinks = []
blurs = []
iterations = []

s0 = 1/resscale * 0.5

for scale in np.logspace(np.log10(16 * resscale), np.log10(resscale), 7):
    if scale < 1:
      break
    shrinks.append(str(int(np.ceil(scale))))
    blurs.append(str(np.sqrt((scale/resscale)**2 - s0**2)))
    iterations.append(str(min(6400, int(np.around(25 * (scale)**3)))))

if resscale > 1:
  for scale in np.logspace(np.log10(resscale), 0, 2):
      shrinks.append(str(int(np.ceil(scale))))
      blurs.append(str(np.sqrt((scale/resscale)**2 - s0**2)))
      iterations.append(str(min(6400, int(np.around(25 * (scale)**3)))))


shrinks.append("1")
blurs.append("0")
iterations.append("25")

#print("x".join(iterations))
#print("x".join(shrinks))
#print("x".join(blurs))

#print("--transform SyN[0.1,3,0]", end=' ')
#print("--metric CC[${fixedfile},${movingfile},1,4]", end=' ')
print("--convergence [{},1e-6,10]".format("x".join(iterations)), end=' ')
print("--shrink-factors {}".format("x".join(shrinks)), end=' ')
print("--smoothing-sigmas {}mm".format("x".join(blurs)), end=' ')
#print("--masks [${fixedmask},${movingmask}]", end=' ')
