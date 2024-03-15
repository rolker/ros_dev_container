#####################
# CUDA and ROS      #
#####################


FROM nvidia/cuda:12.2.2-cudnn8-devel-ubuntu20.04 as ros-cuda

# Install basic apt packages
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    locales \
    lsb-release \
&& rm -rf /var/lib/apt/lists/*
RUN dpkg-reconfigure locales

# Install ROS Noetic
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
RUN apt-get update  && apt-get install -y --no-install-recommends \
    ros-noetic-ros-base \
    python3-rosdep \
&& rm -rf /var/lib/apt/lists/*

RUN rosdep init \
 && rosdep fix-permissions \
 && rosdep update
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc


#####################
# CUDA, ROS, OpenCV #
#####################


FROM ros-cuda as ros-opencv

ARG OPENCV_VERSION=4.9.0
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    wget \
    unzip \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /src/build

RUN wget -q --no-check-certificate https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip -O /src/opencv.zip
RUN wget -q --no-check-certificate https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip -O /src/opencv_contrib.zip

RUN unzip -qq /src/opencv.zip -d /src && rm -rf /src/opencv.zip
RUN unzip -qq /src/opencv_contrib.zip -d /src && rm -rf /src/opencv_contrib.zip

RUN cmake \
  -D OPENCV_EXTRA_MODULES_PATH=/src/opencv_contrib-${OPENCV_VERSION}/modules \
  -D OPENCV_DNN_CUDA=ON \
  -D WITH_CUDA=ON \
  -D BUILD_opencv_python2=OFF \
  -D BUILD_opencv_python3=OFF \
  -D BUILD_TESTS=OFF \
  /src/opencv-${OPENCV_VERSION}

RUN make -j$(nproc)
RUN make install 

WORKDIR /
RUN rm -rf /src/


#####################
# noetic workspace  #
#####################


FROM ros-opencv as noetic-workspace

SHELL [ "/bin/bash" , "-c" ]

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash-completion \
    flite1-dev \
    git \
    less \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstrtspserver-1.0-dev \
    liblivemedia-dev \
    libsnmp-dev \
    nano \
    python3-vcstool \
    wget \
    unzip \
&& rm -rf /var/lib/apt/lists/*    

ARG USERNAME=devuser
ARG UID=1000
ARG GID=${UID}

# Create new user and home directory
RUN groupadd --gid $GID $USERNAME \
 && useradd --uid ${GID} --gid ${UID} --create-home ${USERNAME} \
 && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME} \
 && mkdir -p /home/${USERNAME} \
 && chown -R ${UID}:${GID} /home/${USERNAME} \
 && adduser ${USERNAME} video

RUN ln -s /workspaces /home/${USERNAME}/workspaces

# Set the user and source entrypoint in the user's .bashrc file
USER ${USERNAME}

RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
