FROM ubuntu:latest
LABEL maintainer "Christopher Snyder" <34378288+maliciousactor@users.noreply.github.com>

ENV DEBIAN_FRONTEND=noninteractive
ARG APT="-y --no-install-recommends --no-upgrade -o Dpkg::Options::=--force-confnew"
ENV JDK="https://download.java.net/java/GA/jdk12/GPL/openjdk-12_linux-x64_bin.tar.gz"
ENV WKH="https://builds.wkhtmltopdf.org/0.12.1.4/wkhtmltox_0.12.1.4-1.bionic_amd64.deb"

RUN apt update $APT && \
    apt install $APT \
        android-tools-adb \
        build-essential \
        fontconfig \
        fontconfig-config \
        git \
        libffi-dev \
        libfontconfig1 \
        libjpeg-turbo8 \
        libssl-dev \
        libxext6 \
        libxml2-dev \
        libxrender1 \
        libxslt1-dev \
        locales \
        python3-dev \
        python3-pip \
	python3-setuptools \
        python3.6 \
        sqlite3 \
        wget \
        xfonts-75dpi \
        xfonts-base

RUN locale-gen en_US.UTF-8
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN git clone https://github.com/MobSF/Mobile-Security-Framework-MobSF.git /app

RUN wget --quiet -O /tmp/wkhtmltox_0.12.1.4-1.bionic_amd64.deb "${WKH}" && \
    dpkg -i /tmp/wkhtmltox_0.12.1.4-1.bionic_amd64.deb && \
    apt-get install -f -y --no-install-recommends && \
    ln -s /usr/local/bin/wkhtmltopdf /usr/bin && \
    rm -f /tmp/wkhtmltox_0.12.1.4-1.bionic_amd64.deb

RUN wget --quiet -O /tmp/openjdk-12_linux-x64_bin.tar.gz "${JDK}" && \
    tar zxf /tmp/openjdk-12_linux-x64_bin.tar.gz -C /app && \
    rm -f "openjdk-12_linux-x64_bin.tar.gz"
ENV JAVA_HOME="/app/jdk-12"
ENV PATH="$JAVA_HOME/bin:$PATH"

WORKDIR /app
RUN pip3 install --upgrade wheel && \
    pip3 wheel --wheel-dir=yara-python --build-option="build" --build-option="--enable-dex" git+https://github.com/VirusTotal/yara-python.git@v3.11.0 && \
    pip3 install --no-index --find-links=yara-python yara-python && \
    rm -rf yara-python
RUN pip3 install --quiet --no-cache-dir -r requirements.txt

RUN sed -i 's/USE_HOME = False/USE_HOME = True/g' MobSF/settings.py && \
    sed -i "s#ADB_BINARY = ''#ADB_BINARY = '/usr/bin/adb'#" MobSF/settings.py

ARG POSTGRES=False
WORKDIR /app/scripts
RUN chmod +x postgres_support.sh; sync; ./postgres_support.sh $POSTGRES
WORKDIR /app

RUN mkdir -p /root/.local/share/apktool/framework

EXPOSE 8000
EXPOSE 1337

RUN python3 manage.py makemigrations && \
    python3 manage.py makemigrations StaticAnalyzer && \
    python3 manage.py migrate

CMD ["gunicorn", "-b", "0.0.0.0:8000", "MobSF.wsgi:application", "--workers=1", "--threads=10", "--timeout=1800"]
