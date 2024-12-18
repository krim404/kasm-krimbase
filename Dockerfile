#### Build Stage ####
ARG BASE_IMAGE="debian:bookworm-slim"
FROM $BASE_IMAGE AS base_layer

### Environment config
ARG BG_IMG=bg_kasmos.png
ARG DISTRO=debian
ARG LANG='de_DE.UTF-8'
ARG LANGUAGE='de_DE:de'
ARG LC_ALL='de_DE.UTF-8'
ARG TZ='Etc/UTC'
ENV DEBIAN_FRONTEND=noninteractive \
    DISTRO=$DISTRO \
    HOME=/home/kasm-default-profile \
    INST_SCRIPTS=/dockerstartup/install \
    KASM_VNC_PATH=/usr/share/kasmvnc \
    LANG=$LANG \
    LANGUAGE=$LANGUAGE \
    LC_ALL=$LC_ALL \
    TZ=$TZ \
    STARTUPDIR=/dockerstartup

### Home setup
WORKDIR $HOME
RUN mkdir -p $HOME/Desktop

### Setup package rules
COPY ./src/ubuntu/install/package_rules $INST_SCRIPTS/package_rules/
RUN bash $INST_SCRIPTS/package_rules/package_rules.sh && rm -rf $INST_SCRIPTS/package_rules/

### Install common tools
COPY ./src/ubuntu/install/tools $INST_SCRIPTS/tools/
RUN bash $INST_SCRIPTS/tools/install_tools.sh && rm -rf $INST_SCRIPTS/tools/

### Copy over the maximization script to our startup dir for use by app images.
COPY ./src/ubuntu/install/maximize_script $STARTUPDIR/

### Install custom fonts
COPY ./src/ubuntu/install/fonts $INST_SCRIPTS/fonts/
RUN bash $INST_SCRIPTS/fonts/install_custom_fonts.sh && rm -rf $INST_SCRIPTS/fonts/

### Install KDE
COPY ./src/ubuntu/install/kde $INST_SCRIPTS/kde/
RUN bash $INST_SCRIPTS/kde/install_kde.sh && rm -rf $INST_SCRIPTS/kde/
COPY ./src/ubuntu/install/kde/desktop_environment_policy.sh $STARTUPDIR/
COPY ./src/ubuntu/install/kde/auto_start.desktop $HOME/.config/autostart/apply_policy.desktop

### Install kasm_vnc dependencies and binaries
COPY ./src/ubuntu/install/kasm_vnc $INST_SCRIPTS/kasm_vnc/
RUN bash $INST_SCRIPTS/kasm_vnc/install_kasm_vnc.sh && rm -rf $INST_SCRIPTS/kasm_vnc/
COPY ./src/common/install/kasm_vnc/kasmvnc.yaml /etc/kasmvnc/

### Install Kasm Profile Sync
COPY ./src/ubuntu/install/profile_sync $INST_SCRIPTS/profile_sync/
RUN bash $INST_SCRIPTS/profile_sync/install_profile_sync.sh

### Install Kasm Upload Server
COPY ./src/ubuntu/install/kasm_upload_server $INST_SCRIPTS/kasm_upload_server/
RUN bash $INST_SCRIPTS/kasm_upload_server/install_kasm_upload_server.sh  && rm -rf $INST_SCRIPTS/kasm_upload_server/

### Install Audio
COPY ./src/ubuntu/install/audio $INST_SCRIPTS/audio/
RUN bash $INST_SCRIPTS/audio/install_audio.sh  && rm -rf $INST_SCRIPTS/audio/

### Install Audio Input
COPY ./src/ubuntu/install/audio_input $INST_SCRIPTS/audio_input/
RUN bash $INST_SCRIPTS/audio_input/install_audio_input.sh && rm -rf $INST_SCRIPTS/audio_input/

### Install Gamepad Service
COPY ./src/ubuntu/install/gamepad $INST_SCRIPTS/gamepad/
RUN bash $INST_SCRIPTS/gamepad/install_gamepad.sh && rm -rf $INST_SCRIPTS/gamepad/

### Install Webcam Service
COPY ./src/ubuntu/install/webcam $INST_SCRIPTS/webcam/
RUN bash $INST_SCRIPTS/webcam/install_webcam.sh && rm -rf $INST_SCRIPTS/webcam/

### Install Printer
COPY ./src/ubuntu/install/printer $INST_SCRIPTS/printer/
COPY ./src/ubuntu/install/printer/start_cups.sh /etc/cups/start_cups.sh
RUN bash $INST_SCRIPTS/printer/install_printer.sh && rm -rf $INST_SCRIPTS/printer
COPY ./src/ubuntu/install/printer/resources/*.ppd /etc/cups/ppd/

### Install custom cursors
COPY ./src/ubuntu/install/cursors $INST_SCRIPTS/cursors/
RUN bash $INST_SCRIPTS/cursors/install_cursors.sh && rm -rf $INST_SCRIPTS/cursors/

###
RUN apt install konsole curl dolphin firefox-esr-l10n-de -y

### Install Squid
COPY ./src/ubuntu/install/squid/install/ $INST_SCRIPTS/squid_install/
RUN bash $INST_SCRIPTS/squid_install/install_squid.sh && rm -rf $INST_SCRIPTS/squid_install/
COPY ./src/ubuntu/install/squid/resources/*.conf /etc/squid/
COPY ./src/ubuntu/install/squid/resources/start_squid.sh /etc/squid/start_squid.sh
COPY ./src/ubuntu/install/squid/resources/SN.png /usr/local/squid/share/icons/SN.png
RUN chown proxy:proxy /usr/local/squid/share/icons/SN.png
COPY ./src/ubuntu/install/squid/resources/error_message/access_denied.html /usr/local/squid/share/errors/en/ERR_ACCESS_DENIED
RUN chown proxy:proxy /usr/local/squid/share/errors/en/ERR_ACCESS_DENIED
RUN rm -rf $INST_SCRIPTS/resources/
RUN chmod +x /etc/squid/kasm_squid_adapter
RUN chmod +x /etc/squid/start_squid.sh && chmod 4755 /etc/squid/start_squid.sh

### configure startup 
COPY ./src/common/scripts/kasm_hook_scripts $STARTUPDIR
ADD ./src/common/startup_scripts $STARTUPDIR
RUN bash $STARTUPDIR/set_user_permission.sh $STARTUPDIR $HOME && \
    echo 'source $STARTUPDIR/generate_container_user' >> $HOME/.bashrc

### VirtualGL
COPY ./src/ubuntu/install/virtualgl $INST_SCRIPTS/virtualgl/
RUN bash $INST_SCRIPTS/virtualgl/install_virtualgl.sh && rm -rf $INST_SCRIPTS/virtualgl/

### Sysbox support
COPY ./src/ubuntu/install/sysbox $INST_SCRIPTS/sysbox/
RUN bash $INST_SCRIPTS/sysbox/install_systemd.sh && rm -rf $INST_SCRIPTS/sysbox/

RUN apt install software-properties-common -y && apt-add-repository contrib && apt-add-repository non-free

### Create user and home directory for base images that don't already define it
RUN (groupadd -g 1000 kasm-user \
    && useradd -M -u 1000 -g 1000 -s /bin/bash kasm-user \
    && usermod -a -G kasm-user kasm-user) ; exit 0
ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

### FIX PERMISSIONS ## Objective is to change the owner of non-home paths to root, remove write permissions, and set execute where required
# these files are created on container first exec, by the default user, so we have to create them since default will not have write perm
RUN touch $STARTUPDIR/wm.log \
    && touch $STARTUPDIR/window_manager_startup.log \
    && touch $STARTUPDIR/vnc_startup.log \
    && touch $STARTUPDIR/no_vnc_startup.log \
    && chown -R root:root $STARTUPDIR \
    && find $STARTUPDIR -type d -exec chmod 755 {} \; \
    && find $STARTUPDIR -type f -exec chmod 644 {} \; \
    && find $STARTUPDIR -type f -iname "*.sh" -exec chmod 755 {} \; \
    && find $STARTUPDIR -type f -iname "*.py" -exec chmod 755 {} \; \
    && find $STARTUPDIR -type f -iname "*.rb" -exec chmod 755 {} \; \
    && find $STARTUPDIR -type f -iname "*.pl" -exec chmod 755 {} \; \
    && find $STARTUPDIR -type f -iname "*.log" -exec chmod 666 {} \; \
    && chmod 755 $STARTUPDIR/upload_server/kasm_upload_server \
    && chmod 755 $STARTUPDIR/audio_input/kasm_audio_input_server \
    && chmod 755 $STARTUPDIR/gamepad/kasm_gamepad_server \
    && chmod 755 $STARTUPDIR/webcam/kasm_webcam_server \
    && chmod 755 $STARTUPDIR/printer/kasm_printer_service \
    && chmod 755 $STARTUPDIR/generate_container_user \
    && chmod +x $STARTUPDIR/jsmpeg/kasm_audio_out-linux \
    && rm -rf $STARTUPDIR/install \
    && mkdir -p $STARTUPDIR/kasmrx/Downloads \
    && chown 1000:1000 $STARTUPDIR/kasmrx/Downloads \
    && chown -R root:root /usr/local/bin \
    && chown 1000:root /var/run/pulse \
    && rm -Rf /home/kasm-default-profile/.launchpadlib

### Do Update
RUN apt-get update && apt-get dist-upgrade -y

### Cleanup job
COPY ./src/ubuntu/install/cleanup $INST_SCRIPTS/cleanup/
RUN bash $INST_SCRIPTS/cleanup/cleanup.sh kasmos && rm -rf $INST_SCRIPTS/cleanup/

#### Runtime Stage ####
FROM scratch
COPY --from=base_layer / /

### Labels
LABEL "org.opencontainers.image.authors"='Krim'
LABEL "com.kasmweb.image"="true"

### Environment config
ARG DISTRO=debian
ARG LANG='de_DE.UTF-8'
ARG LANGUAGE='de_DE:de'
ARG LC_ALL='de_DE.UTF-8'
ARG START_PULSEAUDIO=1
ARG START_DE=kde5
ARG TZ='Etc/UTC'
ENV AUDIO_PORT=4901 \
    DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    DISTRO=$DISTRO \
    GOMP_SPINCOUNT=0 \
    HOME=/home/kasm-user \
    INST_SCRIPTS=/dockerstartup/install \
    KASMVNC_AUTO_RECOVER=true \
    KASM_VNC_PATH=/usr/share/kasmvnc \
    LANG=$LANG \
    LANGUAGE=$LANGUAGE \
    LC_ALL=$LC_ALL \
    LD_LIBRARY_PATH=/opt/libjpeg-turbo/lib64/:/usr/local/lib/ \
    LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}:/usr/local/nvidia/lib:/usr/local/nvidia/lib64 \
    MAX_FRAME_RATE=24 \
    NO_VNC_PORT=6901 \
    NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics,compat32,utility \
    OMP_WAIT_POLICY=PASSIVE \
    PULSE_RUNTIME_PATH=/var/run/pulse \
    SDL_GAMECONTROLLERCONFIG="030000005e040000be02000014010000,XInput Controller,platform:Linux,a:b0,b:b1,x:b2,y:b3,back:b8,guide:b16,start:b9,leftstick:b10,rightstick:b11,leftshoulder:b4,rightshoulder:b5,dpup:b12,dpdown:b13,dpleft:b14,dpright:b15,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:b6,righttrigger:b7" \
    SHELL=/bin/bash \
    START_PULSEAUDIO=$START_PULSEAUDIO \
    STARTUPDIR=/dockerstartup \
    START_DE=$START_DE \
    TERM=xterm \
    VNC_COL_DEPTH=24 \
    VNCOPTIONS="-PreferBandwidth -DynamicQualityMin=4 -DynamicQualityMax=7 -DLP_ClipDelay=0" \
    VNC_PORT=5901 \
    VNC_PORT=5901 \
    VNC_PW=vncpassword \
    VNC_RESOLUTION=1280x1024 \
    VNC_RESOLUTION=1280x720 \
    VNC_VIEW_ONLY_PW=vncviewonlypassword \
    TZ=$TZ

### Ports and user
EXPOSE $VNC_PORT \
       $NO_VNC_PORT \
       $UPLOAD_PORT \
       $AUDIO_PORT
WORKDIR $HOME
USER 1000

ENTRYPOINT ["/dockerstartup/kasm_default_profile.sh", "/dockerstartup/vnc_startup.sh", "/dockerstartup/kasm_startup.sh"]
CMD ["--wait"]

