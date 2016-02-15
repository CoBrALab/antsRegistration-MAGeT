#MAGeT Reimplementation

File types supported is mnc, nii, nii.gz, maybe others

input/
    atlas/
        BASENAME_t1.ext
        [BASENAME_t2.ext] - coregistered to T1
        BASENAME_label1.ext
        [BASENAME_label2.ext] - additional labels
        [BASENAME_labelN.ext] - arbitrary numbers of labels
        [BASENAME_mask.ext] - brain mask, used in later registration stages
    template/
        BASENAME_t1.ext
        [BASENAME_t2.ext] - coregistered to T1
        [BASENAME_mask.ext] - brain mask, used in later registration stages
    subject/
        BASENAME_t1.ext
        [BASENAME_t2.ext] - coregistered to T1
        [BASENAME_mask.ext] - brain mask, used in later registration stages

#Basic Implementation

Stage1 <all registrations independent>
Job names ISODATETIME-mb_template
antsRegistration of atlas->template
 - use COM mode in ants
 - rigid registration
 - no mask
+
 - affine with headmask
+
 - affine with brainmask
+
 - nonlinear with brainmask

Stage2 <all registrations independent>
Job names ISODATETIME-mb_subject-subjectfilename
antsRegistration of template->subject
 - use COM mode in ants
 - rigid registration
 - no mask

+ 
 - affine with brainmask
 - nonlinear with brainmask

Stage3 <depends on mb_template && mb_subject_subjectfilename>
Job names ISODATETIME-mb_resample-subjectfilename
Apply transforms of labels atlas->template->subject
- antsApplyTransforms

Stage4 <depends on mb_resample-subjectfilename>
Job name ISODATETIME-mb_vote-subjectfilename
Voting of final labels
- MajorityVoting
- STAPLE

Memory/Timing Issues
Using 1x1x1 atlas and SyN registration 2.93GB per registration, ~2 hours

Using full-res atlas runs out of RAM on 16GB nodes, should we use 32GB nodes for atlas-template?
