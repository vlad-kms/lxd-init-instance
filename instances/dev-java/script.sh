#!/bin/bash
#script.sh
#VER=$(curl --silent -qI https://github.com/bakito/adguardhome-sync/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}'); \
#wget https://github.com/bakito/adguardhome-sync/releases/download/$VER/adguardhome-sync_${VER#v}_linux_x86_64.tar.gz

log_file="/var/log/123-123.log" 
echo "$(date +"+%d-%m-%Y-%H-%M-%S") ===========================" >> "$log_file"
name_file="asdf"
cd "$HOME"

VER=$(curl --silent -qI https://github.com/asdf-vm/asdf/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
echo "VER: $VER" >> "$log_file"
curl -L --silent -o "${name_file}.zip" "https://github.com/asdf-vm/asdf/archive/refs/tags/${VER}.zip"
unzip -o "${name_file}.zip" > /dev/null
rm "${name_file}.zip"

dirname="${name_file}-$(echo $VER | sed -En 's/v(.*)$/\1/p')"
echo "dirname: $dirname" >> "$log_file"
#exit

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
