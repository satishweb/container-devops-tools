# Author: Satish Gaikwad <satish@satishweb.com>
FROM public.ecr.aws/ubuntu/ubuntu:22.04
LABEL MAINTAINER "Satish Gaikwad <satish@satishweb.com>"

ENV DEBIAN_FRONTEND noninteractive
ENV FIXUID_VERSION 0.6.0

RUN apt-get update

# Disable auto installation of recommended packages, too many unwanted packages gets installed without this 
RUN apt-config dump | grep -we Recommends -e Suggests | sed s/1/0/ | tee /etc/apt/apt.conf.d/999norecommend

# Install basic system packages
RUN apt-get install -y \
    ca-certificates \
    software-properties-common \
    && apt clean -y

# Install desktop environment and other system tools
RUN apt-get -y install \
    vim \
    jq \
    less \
    multitail \
    bash \
    bash-completion \
    binutils \
    file \
    iputils-ping \
    sudo \
    zsh \
    wget \
    curl \
    tmux \
    sshcommand \
    sshuttle \
    git \
    python3 \
    python3-pip \
    python3-virtualenv \
    locales \
    build-essential \
    apt-utils \
    openssh-client \
    gnupg2 \
    iproute2 \
    procps \
    lsof \
    htop \
    net-tools \
    psmisc \
    rsync \
    ca-certificates \
    unzip \
    zip \
    nano \
    vim-tiny \
    lsb-release \
    apt-transport-https \
    dialog \
    libc6 \
    libgcc1 \
    libkrb5-3 \
    libgssapi-krb5-2 \
    libstdc++6 \
    zlib1g \
    ncdu \
    man-db \
    strace \
    manpages \
    manpages-dev \
    manpages-posix \
    manpages-posix-dev \
    zsh \
    && apt clean -y


RUN locale-gen en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

## User Config
RUN groupadd -g 1000 ubuntu
RUN useradd -u 1000 -g 1000 -d /home/ubuntu -s /bin/zsh -c "Linux User" ubuntu

# Allow DevOps user to be sudo to install any new packages
RUN usermod -a -G sudo ubuntu
RUN echo '1000 ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN echo '%ubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN mkdir -p /home/ubuntu/.local/bin
RUN chown -Rf ubuntu:ubuntu /home/ubuntu

# Install fixuid to allow change of uid and gid runtime
RUN USER=ubuntu && \
    GROUP=ubuntu && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL https://github.com/boxboat/fixuid/releases/download/v${FIXUID_VERSION}/fixuid-${FIXUID_VERSION}-${OS}-${ARCH}.tar.gz | tar -C /usr/local/bin -xzf - && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: $USER\ngroup: $GROUP\npaths:\n  - /home/ubuntu\n" > /etc/fixuid/config.yml && \
    echo "FIXUID: ${FIXUID_VERSION}" | sudo tee -a /versions

#### Install tools
# Install docker cli
RUN curl -sSfL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

RUN apt-get update \
  && apt-get -y install \
    python3-pygments \
    docker-ce-cli \
    docker-compose-plugin \
    docker-buildx-plugin \
    terraform \
    packer \
    unzip \
    pass \
    dnsutils \
    bsdmainutils \
    groff \
    nano \
    gh \
    mtr \
    ranger \
  && rm -rf /var/cache/apt/archives/*deb

USER ubuntu:ubuntu
ENV HOME /home/ubuntu
WORKDIR /home/ubuntu

# Install Oh My ZSH
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

ARG KUBECTL_VERSION v1.27.3

# Install awscli2
RUN cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/\(arm\)\(64\)\?.*/\1\2/')" && \
    curl -sSfL -o awscli.zip https://awscli.amazonaws.com/awscli-exe-${OS}-${ARCH}.zip && \
    unzip awscli.zip && \
    sudo ./aws/install && \
    rm -rf aws *.zip && \
    echo "AWS CLI: $(aws --version)" | sudo tee -a /versions

# Install kubectl
RUN cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfLO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl && \
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl && \
    echo "KUBECTL: ${KUBECTL_VERSION}" | sudo tee -a /versions

# Install eksctl
RUN cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_${OS}_${ARCH}.tar.gz | tar xz -C . && \
    sudo install -o root -g root -m 0755 eksctl /usr/local/bin/eksctl && \
    rm eksctl && \
    echo "EKSCTL: $(eksctl version)" | sudo tee -a /versions

# Install k9s
RUN cd "$(mktemp -d)" && \
    OS="$(uname)" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL https://github.com/derailed/k9s/releases/latest/download/k9s_${OS}_${ARCH}.tar.gz | tar xz -C . && \
    sudo install -o root -g root -m 0755 k9s /usr/local/bin/k9s && \
    rm k9s && \
    echo "K9S: $(k9s version|grep Version|awk -F '[:]' '{print $2}'|sed 's/ //g')" | sudo tee -a /versions

# Install kind
RUN cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL -o ./kind https://kind.sigs.k8s.io/dl/v0.18.0/kind-${OS}-${ARCH} && \
    sudo install -o root -g root -m 0755 kind /usr/local/bin/kind && \
    rm kind && \
    echo "KIND: $(kind --version|awk '{print $3}')" | sudo tee -a /versions

# Install Terragrunt
RUN cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL -o ./terragrunt https://github.com/gruntwork-io/terragrunt/releases/download/v0.45.2/terragrunt_${OS}_${ARCH} && \
    sudo install -o root -g root -m 0755 terragrunt /usr/local/bin/terragrunt && \
    rm terragrunt && \
    echo "TERRAGRUNT: $(terragrunt --version|awk '{print $3}')" | sudo tee -a /versions

# Install terrascan
RUN cd "$(mktemp -d)" && \
    ARCH="$(uname -m | sed -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL $(curl -s https://api.github.com/repos/tenable/terrascan/releases/latest | grep -o -E "https://.+?_Linux_${ARCH}.tar.gz") > terrascan.tar.gz && \
    tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz && \
    sudo install -o root -g root -m 0755 terrascan /usr/local/bin/terrascan && \
    rm terrascan && \
    echo "TERRASCAN: $(terrascan version|awk '{print $2}')" | sudo tee -a /versions

# Install tfsec
RUN curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash && \
    echo "TFSEC: $(tfsec --version)" | sudo tee -a /versions

# Install tflint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash && \
    echo "TFLINT: $(tflint --version|grep version|awk '{print $3}')" | sudo tee -a /versions

# Install krew
RUN cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    KREW="krew-${OS}_${ARCH}" && \
    curl -fsSLO https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz && \
    tar zxvf "${KREW}.tar.gz" && \
    sudo install -o root -g root -m 0755 "${KREW}" /usr/local/bin/kubectl-krew && \
    rm "${KREW}" *.tar.gz && \
    echo "KREW: $(kubectl-krew version|grep GitTag|awk '{print $2}')" | sudo tee -a /versions

# Install plugins that are available only for amd64 platform
RUN OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    if [ "${OS}" = "linux" ] && [ "${ARCH}" = "amd64" ]; then \
        kubectl krew install \
            doctor \
            sniff \
            trace \
            unused-volumes \
            virt \
            cost \
            df-pv \
            evict-pod \
            get-all \
            htpasswd \
            kyverno \
            oomd \
            rbac-lookup \
            resource-versions \
            sniff \
            tree \
            viewnode ;\
    else \
        echo "Warn: Some of the krew plugins have binaries only for amd64 platform" ;\
    fi

RUN kubectl krew install \
      allctx \
      auth-proxy \
      ca-cert \
      cert-manager \
      ctx \
      exec-as node-shell \
      ns \
      tail \
      view-cert \
      whoami \
      blame \
      bulk-action \
      capture \
      colorize-applied \
      config-registry \
      confirm \
      datree \
      debug-shell \
      eksporter \
      exec-as \
      exec-cronjob \
      explore \
      graph \
      grep \
      iexec \
      images \
      ktop \
      log2rbac \
      mtail \
      node-shell \
      oidc-login \
      preflight \
      pv-migrate \
      rbac-tool \
      rename-pvc \
      resource-capacity \
      restart \
      rolesum \
      sick-pods \
      snap \
      ssh-jump \
      support-bundle \
      tmux-exec \
      ttsum \
      view-allocations \
      view-secret \
      view-utilization \
      who-can

# Install helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \
    echo "HELM: $(helm version)" | sudo tee -a /versions

# Install argocd
RUN cd $(mktemp -d) && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-${OS}-${ARCH} && \
    sudo install -m 555 argocd /usr/local/bin/argocd && \
    rm argocd && \
    echo "ARGOCD: $(argocd version 2>/dev/null|grep -e '^argocd:'|awk '{print $2}')" | sudo tee -a /versions

# Install SAML2AWS
RUN OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    VERSION=2.36.13 && \
    wget -c "https://github.com/Versent/saml2aws/releases/download/v${VERSION}/saml2aws_${VERSION}_${OS}_${ARCH}.tar.gz" -O - | tar -xzv -C ~/.local/bin && \
    chmod u+x ~/.local/bin/saml2aws && \
    echo "SAML2AWS: $(~/.local/bin/saml2aws --version)" | sudo tee -a /versions

ENV SAML2AWS_KEYRING_BACKEND pass

# Vcluster
RUN cd $(mktemp -d) && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL -o vcluster https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-${OS}-${ARCH} && \
    sudo install -c -m 0755 vcluster /usr/local/bin && \
    rm -f vcluster && \
    echo "VCLUSTER: $(vcluster --version|awk '{print $3}')" | sudo tee -a /versions

# devpod
RUN cd $(mktemp -d) && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL -o devpod https://github.com/loft-sh/devpod/releases/latest/download/devpod-${OS}-${ARCH} && \
    sudo install -c -m 0755 devpod /usr/local/bin && \
    rm -f devpod && \
    echo "DEVPOD: $(devpod version)" | sudo tee -a /versions

# Telepresence
RUN cd $(mktemp -d) && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL -o telepresence https://app.getambassador.io/download/tel2/${OS}/${ARCH}/latest/telepresence && \
    sudo install -c -m 0755 telepresence /usr/local/bin && \
    rm -f telepresence && \
    echo "TELEPRESENCE: $(telepresence version|grep Client|awk '{print $3}')" | sudo tee -a /versions

# DevSpace
RUN cd $(mktemp -d) && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL -o devspace https://github.com/loft-sh/devspace/releases/latest/download/devspace-${OS}-${ARCH} && \
    sudo install -c -m 0755 devspace /usr/local/bin && \
    rm -f devspace && \
    echo "DEVSPACE: $(devspace version|awk '{print $4}')" | sudo tee -a /versions

# skaffold
RUN cd $(mktemp -d) && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    curl -sSfL -o skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-${OS}-${ARCH} && \
    sudo install -c -m 0755 skaffold /usr/local/bin && \
    rm -f skaffold && \
    echo "SKAFFOLD: $(skaffold version)" | sudo tee -a /versions

# Pre-commit
RUN pip3 install pre-commit && \
    echo "PRE-COMMIT: $(pre-commit --version|awk '{print $2}')" | sudo tee -a /versions

# Kubetail
RUN git clone https://github.com/johanhaleby/kubetail.git ${HOME}/.oh-my-zsh/custom/plugins/kubetail && \
    echo "kubetail: $(kubetail --version)" | sudo tee -a /versions

# zsh-autosuggestions
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# zsh-syntax-highlighting
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# kube-ps1
RUN git clone https://github.com/jonmosco/kube-ps1.git ${HOME}/.oh-my-zsh/custom/plugins/kube-ps1

# AI YAI
RUN curl -sS https://raw.githubusercontent.com/ekkinox/yai/main/install.sh | sudo bash && mkdir -p ~/.config

RUN sudo groupadd docker ;\
    sudo usermod -aG docker ubuntu

ENV TERM xterm-256color

# Copy default configs
# Note: if you have a personalized tmux config, just mount it inside the container at runtime
COPY files/.kubectl_aliases ${HOME}/.kubectl_aliases
COPY files/.aws_cli_functions ${HOME}/.aws_cli_functions
COPY files/.zshrc ${HOME}/.zshrc
COPY files/.tmux.conf ${HOME}/.tmux.conf
COPY files/yai.json ${HOME}/.config/yai.json

# Disable VIM visual mode
RUN echo "set mouse-=a" >> ~/.vimrc

COPY entrypoint.sh /entrypoint.sh
RUN sudo chmod u+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD [ "/bin/zsh" ]
