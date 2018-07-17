#!/usr/bin/env python
from sklearn.cross_validation import StratifiedShuffleSplit,ShuffleSplit
import numpy as np
import pandas
import os

folds=5
num_atlases=2
num_templates=2
inputs = pandas.read_csv("list.csv")
groups =  inputs.iloc[:,1]

try:
    sss_atlas = StratifiedShuffleSplit(y = groups, n_iter=folds, train_size=num_atlases, test_size=len(inputs)-num_atlases)
except ValueError:
    sss_atlas = ShuffleSplit(len(groups), n_iter=folds, train_size=num_atlases, test_size=len(inputs)-num_atlases)

for atlas_index, test_index in sss_atlas:
    print("Atlases:", len(atlas_index))
    atlases = inputs.iloc[atlas_index,0]
    test = inputs.iloc[test_index,0]
    test_types = inputs.iloc[test_index,1]
    try:
        sss_templates = StratifiedShuffleSplit(y = test_types, n_iter=1, train_size=num_templates, test_size=len(test_types)-num_templates)
    except ValueError:
        sss_templates = ShuffleSplit(len(test_types), n_iter=1, train_size=num_templates, test_size=len(test_types)-num_templates)
    for template_index, subject_index in sss_templates:
        print("Templates:", len(template_index), "Subjects:", len(subject_index))
        templates = test.iloc[template_index]
        subjects = test.iloc[subject_index]
    #This code guarantees that the number of atlases and templates requested is given
    #As a result it slightly breaks the stratification, so we do it in a random fashion
    while len(atlases) < num_atlases:
        randid = np.random.randint(len(subjects))
        atlases = atlases.append(subjects[randid:randid+1])
        subjects.drop(subjects.index[randid], inplace=True)
    while len(atlases) > num_atlases:
        randid = np.random.randint(len(atlases))
        subjects = subjects.append(atlases[randid:randid+1])
        atlases.drop(atlases.index[randid], inplace=True)
    while len(templates) < num_templates:
        randid = np.random.randint(len(subjects))
        templates = templates.append(subjects[randid:randid+1])
        subjects.drop(subjects.index[randid], inplace=True)
    while len(templates) > num_templates:
        randid = np.random.randint(len(templates))
        subjects = subjects.append(templates[randid:randid+1])
        templates.drop(templates.index[randid], inplace=True)
    print len(atlases)
    print len(templates)
    print len(subjects)
    print "Atlases:"
    for atlas in atlases:
        print atlas
    # print "Templates:"
    # for template in templates:
    #    print template
    # print "Subjects:"
    # for subject in subjects:
    #    print subject
