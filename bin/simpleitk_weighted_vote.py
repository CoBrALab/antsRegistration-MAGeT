#!/usr/bin/env python

from __future__ import division, print_function

import os.path
import sys
from argparse import ArgumentParser
from warnings import warn

import numpy as np

import SimpleITK as sitk

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("-o", "--output", type=str)
    parser.add_argument("input_labels", nargs="+", type=str)
    parser.add_argument(
        "-v",
        "--verbose",
        dest="verbose",
        action="store_true",
        default=False,
        help="[default = %(default)s]",
    )
    parser.add_argument(
        "--clobber",
        dest="clobber",
        action="store_true",
        default=False,
        help="clobber output file [default = %(default)s]",
    )
    parser.add_argument(
        "--weights",
        nargs="+",
        type=float,
        help="(negative) weights for voting, if not provided, equal weights",
    )
    parser.add_argument(
        "-p",
        "--probabilities",
        dest="probabilities",
        action="store_true",
        default=False,
        help="Save per-label probability maps",
    )
    opt = parser.parse_args()

    if not (opt.clobber) and os.path.exists(opt.output):
        sys.exit("Output file already exists; use --clobber to overwrite.")

    if not opt.weights:
        opt.weights = [-1.0] * len(opt.input_labels)

    if len(opt.weights) > 0:
        if len(opt.weights) != len(opt.input_labels):
            sys.exit("Weights provided not equal to number of input labels")

    # load volumes from input files
    labelimg_list = []  # list of candidate segmentation images

    # use this to verify if the voxel-wise computations make sense
    def check_metadata(img, metadata, filename):
        if img.GetSize() != metadata["size"]:
            sys.exit(
                "Size of {0} not the same as {1}".format(filename, opt.input_labels[0])
            )
        elif img.GetOrigin() != metadata["origin"]:
            sys.exit(
                "Origin of {0} not the same as {1}".format(
                    filename, opt.input_labels[0]
                )
            )
        elif img.GetSpacing() != metadata["spacing"]:
            sys.exit(
                "Spacing of {0} not the same as {1}".format(
                    filename, opt.input_labels[0]
                )
            )
        elif img.GetDirection() != metadata["direction"]:
            sys.exit(
                "Direction of {0} not the same as {1}".format(
                    filename, opt.input_labels[0]
                )
            )

    for filename in opt.input_labels:
        if opt.verbose:
            print("Reading labels from {}...".format(filename))

        # get all the candidate segmentations
        labelimg = sitk.ReadImage(filename, sitk.sitkUInt32)

        structure = labelimg > 0  # find the structural voxels
        label_shape_analysis = sitk.LabelShapeStatisticsImageFilter()
        label_shape_analysis.SetBackgroundValue(0)
        label_shape_analysis.Execute(structure)
        b = label_shape_analysis.GetBoundingBox(1)  # get the bounding box

        if len(labelimg_list) == 0:
            metadata = {}  # get the metadata of the first image
            metadata["size"] = labelimg.GetSize()
            metadata["origin"] = labelimg.GetOrigin()
            metadata["spacing"] = labelimg.GetSpacing()
            metadata["direction"] = labelimg.GetDirection()

            # get the first bounding box
            bbox = [b[0], b[1], b[2], b[0] + b[3], b[1] + b[4], b[2] + b[5]]

        else:  # check that the metadata is the same for each other image
            check_metadata(labelimg, metadata, filename)

            new_bbox = (b[0], b[1], b[2], b[0] + b[3], b[1] + b[4], b[2] + b[5])
            for i in range(0, 3):  # for each minimum bounding box index
                if new_bbox[i] < bbox[i]:
                    bbox[i] = new_bbox[i]  # keep the new minimum
            for i in range(3, 6):  # for each maximum bounding box index
                if new_bbox[i] > bbox[i]:
                    bbox[i] = new_bbox[i]  # keep the new maximum

        labelimg_list.append(labelimg)

    if opt.verbose:
        print("Computing weighted votes...")

    nimg = len(labelimg_list)
    for n, img in enumerate(labelimg_list):
        if opt.verbose:
            print("Processing image {}, {} of {}".format(opt.input_labels[n], n+1, nimg))

        label_array = sitk.GetArrayFromImage(img)[
            bbox[2] : bbox[5], bbox[1] : bbox[4], bbox[0] : bbox[3]
        ]

        if n == 0:
            label_values = np.unique(label_array)  # obtain the list of labels
            votes = np.zeros(
                (
                    label_values.shape[0],
                    label_array.shape[0],
                    label_array.shape[1],
                    label_array.shape[2],
                ),
            dtype=np.float64)
        # make sure that they are the same in each image
        elif np.asarray(np.unique(label_array) != label_values).any():
            warn(
                "Labels in image {0} not the same as in image {1}.".format(
                    opt.input_labels[n], opt.input_labels[0]
                )
            )

        for i, value in enumerate(label_values):
            # count the votes for each label
            votes[i][np.where(label_array == value)] += opt.weights[n]

    mode = np.argmin(votes, axis=0)  # find the majority votes
    if opt.probabilities:
      probability = votes / np.sum(opt.weights)  # Find probability maps
    labels = np.zeros(votes[0].shape, dtype=np.uint32)  # array of labels

    for i, value in enumerate(label_values.tolist()):
        # assign the majority vote to all voxels
        labels[np.where(mode == i)] = value

    labels = np.pad(
        labels,
        (
            (bbox[2], labelimg.GetDepth() - bbox[5]),
            (bbox[1], labelimg.GetHeight() - bbox[4]),
            (bbox[0], labelimg.GetWidth() - bbox[3]),
        ),
        "constant",
        constant_values=0,
    )

    if opt.verbose:
        print("Writing output labels to {}...".format(opt.output))

    output_image = sitk.GetImageFromArray(labels)
    output_image.CopyInformation(labelimg)  # copy the metadata

    # save the result to the output file
    sitk.WriteImage(output_image, opt.output, True)

    if opt.probabilities:
        for i, value in enumerate(label_values.tolist()):
            if value != 0:
                # assign the majority vote to all voxels
                probability_map = np.pad(
                    probability[i],
                    (
                        (bbox[2], labelimg.GetDepth() - bbox[5]),
                        (bbox[1], labelimg.GetHeight() - bbox[4]),
                        (bbox[0], labelimg.GetWidth() - bbox[3]),
                    ),
                    "constant",
                    constant_values=0,
                )
                output_image = sitk.GetImageFromArray(probability_map)
                output_image.CopyInformation(labelimg)  # copy the metadata
                if opt.verbose:
                    print(
                        "Writing probability map to {}...".format(
                            opt.output.rsplit(".nii")[0].rsplit(".mnc")[0]
                            + "_"
                            + str(value)
                            + ".mnc"
                        )
                    )
                # save the result to the output file
                sitk.WriteImage(
                    output_image,
                    opt.output.rsplit(".nii")[0].rsplit(".mnc")[0]
                    + "_"
                    + str(value)
                    + ".mnc",
                    True,
                )
