# Use an image with pre-built ANTs included
FROM gdevenyi/magetbrain-bids-ants:1c5634faf5ba8afa0a12c71f8b0d8de774fb6e75

RUN apt-get update \
    && apt-get install --auto-remove --no-install-recommends -y parallel \
    && apt-get update \
    && apt-get install -y --no-install-recommends --auto-remove git curl unzip \
    && curl -o anaconda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash anaconda.sh -b -p /opt/anaconda && rm -f anaconda.sh \
    && git clone  https://github.com/CobraLab/antsRegistration-MAGeT.git /opt/antsRegistration-MAGeT \
    && (cd /opt/antsRegistration-MAGeT && git checkout 17f9f01ab171db85d50be41c228e686ecb10facb) \
    && apt-get purge --auto-remove -y git curl unzip \
    && rm -rf /var/lib/apt/lists/*

ENV CONDA_PATH "/opt/anaconda"

RUN /opt/anaconda/bin/pip install https://github.com/pipitone/qbatch/archive/8f63062784e54ea6de6fd08b453d881dd4703368.zip

ENV PATH /opt/ANTs/bin:/opt/anaconda/bin:/opt/antsRegistration-MAGeT/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN mkdir -p /scratch

ENV QBATCH_SYSTEM container
ENV QBATCH_SCRIPT_FOLDER magetbrain-container-jobs/
