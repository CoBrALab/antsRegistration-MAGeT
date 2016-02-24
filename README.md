#MAGeT Implementation with antsRegistration

File types supported is mnc, nii, nii.gz, maybe others, in theory whatever ANTs supports

#How to get/run
```sh
> git clone --recursive https://github.com/CobraLab/antsRegistration-MAGeT.git
> source antsRegistration-MAGeT/bin/activate
# Setup an input directory as per below
# Make sure ANTs tools are available (ex: module load scinet or module load ANTs/git)
> mb.sh
```


# File/Directory Structure

```
#Assuming one atlas, one subject, on template, generalize for N...
input/
    atlas/
        atlas1_t1.ext
        <atlas1_t2.ext> - coregistered to T1
        atlas1_label_name.ext
        <atlas1_label_name2.ext> - additional labels
        <atlas1_label_nameN.ext> - arbitrary numbers of labels
        <atlas1_mask.ext> - brain mask, used to concentrate registration
        ....
    template/
        subject1_t1.ext - filename should match subject with same MRI
        <subject1_t2.ext> - coregistered to T1, requires atlas to also have this contrast
        <subject1_mask.ext> - brain mask, used to concentrate registration
        ....
    subject/
        subject1_t1.ext
        <subject1_t2.ext> - coregistered to T1, requires template to also have this contrast
        <subject1_mask.ext> - brain mask, used to concentrate registration
        ....
output/
    transforms/
        atlas-template/
            template1_t1.ext/
                atlas1_t1.ext-template1_t1.ext0_GenericAffine.xfm
                atlas1_t1.ext-template1_t1.ext1_NL.xfm
        template-subject/
            subject1_t1.ext/
                template1_t1.ext-subject1_t1.ext0_GenericAffine.xfm
                template1_t1.ext-subject1_t1.ext1_NL.xfm
    labels/
        candidates/
            subject1_t1.ext/
                atlas1_t1.ext-template1_t1.ext-subject1_t1.ext-atlas1_label_name.ext                   
                
        majorityvote/
            subject1_label_name.ext
```


