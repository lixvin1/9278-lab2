#!/bin/bash

dir="$1"
malicious_dir="$2"
interval_secs="$3"

scan_dir() {
  for file in "$dir"/*; do
    if [ -f "$file" ]; then
      filename=$(basename "$file")
      malicious=0

      case "$filename" in
        *.exe|*.bat|*.vbs|*.scr|*.ps1)
          malicious=1
          ;;
      esac

      if grep -qiE 'virus|trojan|malware|worm|ransomware' "$file"; then
        malicious=1
      fi

      if [ "$malicious" -eq 1 ]; then
        echo "$filename is malicious and it is DELETED"
        cp "$file" "$malicious_dir/"
        rm "$file"
      fi
    fi
  done
}

if [ ! -f directory-info.last ]; then
  scan_dir
  ls -l "$dir" > directory-info.last
fi

while true; do
  ls -l "$dir" > directory-info.new

  if cmp -s directory-info.last directory-info.new ; then
    sleep "$interval_secs"
  else
    scan_dir
    ls -l "$dir" > directory-info.last
    sleep "$interval_secs"
  fi
done
