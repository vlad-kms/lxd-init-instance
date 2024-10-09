#!/bin/bash
#script.sh
#VER=$(curl --silent -qI https://github.com/bakito/adguardhome-sync/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}'); \
#wget https://github.com/bakito/adguardhome-sync/releases/download/$VER/adguardhome-sync_${VER#v}_linux_x86_64.tar.gz

log_file="/var/log/123-123.log" 
echo "$(date +"+%d-%m-%Y-%H-%M-%S") ===========================" >> "$log_file"

cd "$HOME"

# установка asdf
name_file="asdf"
VER=$(curl --silent -qI https://github.com/asdf-vm/asdf/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
echo "VER: $VER" >> "$log_file"
echo "DEBUG: $DEBUG" >> "$log_file"
if [[ $DEBUG -ne 0 ]]; then
  echo "VER: $VER" >&2
fi
curl -L --silent -o "${name_file}.zip" "https://github.com/asdf-vm/asdf/archive/refs/tags/${VER}.zip"
unzip -o "${name_file}.zip" > /dev/null
rm "${name_file}.zip"

dirname="${name_file}-$(echo $VER | sed -En 's/v(.*)$/\1/p')"
echo "dirname: $dirname" >> "$log_file"
if [[ $DEBUG -ne 0 ]]; then
  echo "dirname: $dirname" >&2
fi

# удалить файл и каталог  если есть с таким именем ".${name_file}"
if [ -d "${HOME}/.${name_file}" ]; then
    rm -r "${HOME}/.$name_file"
fi
if [ -f "${HOME}/.${name_file}" ]; then
    find "${HOME}" -name  ".${name_file}" -exec rm {} \;
fi

mv "$dirname" "${HOME}/.${name_file}" > /dev/null
echo ". $HOME/.${name_file}/asdf.sh" >> "$HOME/.bashrc"
echo ". $HOME/.${name_file}/completions/asdf.bash" >> "$HOME/.bashrc"
export ASDF_DIR="${HOME}/.${name_file}"
printenv >> "$log_file"
if [[ $DEBUG -ne 0 ]]; then
  printenv
fi
source ${HOME}/.bashrc

# добавить maven
ver_mvn='3.9.9'
if [[ $DEBUG -ne 0 ]]; then
  asdf plugin add maven https://github.com/halcyon/asdf-maven.git >&2
else
  asdf plugin add maven https://github.com/halcyon/asdf-maven.git >&2 2>/dev/null
fi
# install version maven
if [[ $DEBUG -ne 0 ]]; then
  asdf install maven "${ver_mvn}" >&2
  asdf global  maven "${ver_mvn}" >&2
else
  asdf install maven "${ver_mvn}" >&2 2>/dev/null
  asdf global  maven "${ver_mvn}" >&2 2>/dev/null
fi

# добавить java
ver_jdk='openjdk-17.0.2'
if [[ $DEBUG -ne 0 ]]; then
  asdf plugin add java https://github.com/halcyon/asdf-java.git >&2
else
  asdf plugin add java https://github.com/halcyon/asdf-java.git >&2 2>/dev/null
fi
# install version JDK
if [[ $DEBUG -ne 0 ]]; then
  asdf install java "${ver_jdk}" >&2
  asdf global  java "${ver_jdk}" >&2
else
  asdf install java "${ver_jdk}" >&2 2>/dev/null
  asdf global  java "${ver_jdk}" >&2 2>/dev/null
fi
