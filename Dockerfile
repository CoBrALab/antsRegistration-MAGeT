# Use an image with pre-built ANTs included
FROM gdevenyi/magetbrain-bids-ants:3e034a3a10de69e5bfb2046609931c654c2e4ad4

RUN apt-get update \
    && apt-get install --auto-remove --no-install-recommends -y parallel \
    && apt-get update \
    && apt-get install -y --no-install-recommends --auto-remove git curl unzip \
    && curl -o anaconda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash anaconda.sh -b -p /opt/anaconda && rm -f anaconda.sh \
    && git clone  https://github.com/CobraLab/antsRegistration-MAGeT.git /opt/antsRegistration-MAGeT \
    && (cd /opt/antsRegistration-MAGeT && git checkout bed6e1c45fc10e4de5be75a24119997a59803ee8) \
    && apt-get purge --auto-remove -y git curl unzip \
    && rm -rf /var/lib/apt/lists/*

ENV CONDA_PATH "/opt/anaconda"

RUN /opt/anaconda/bin/pip install https://github.com/pipitone/qbatch/archive/8f63062784e54ea6de6fd08b453d881dd4703368.zip

ENV PATH /opt/ANTs/bin:/opt/anaconda/bin:/opt/antsRegistration-MAGeT/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ENV QBATCH_SYSTEM container
ENV QBATCH_SCRIPT_FOLDER magetbrain-container-jobs/
