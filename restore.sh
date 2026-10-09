#!/bin/bash

dir="$1"
malicious_dir="$2"

if [ -z "$(ls -A "$malicious_dir")" ]; then
  echo "No malicious files to review."
  exit 0
fi

while true; do
  files=("$malicious_dir"/*)
  i=1
echo "Choose a file:"
  for f in "${files[@]}"; do
    filename=$(basename "$f")
    echo "$i: $filename"
    i=$((i+1))
  done

  read -p ">" x

  fullselectedfilepath="${files[$((x-1))]}"
  selectedfilename=$(basename "$fullselectedfilepath")

  echo "For $selectedfilename:"
  echo "1: Restore this file back into dir (it was a false positive)"
  echo "2: Permanently delete this file from malicious_dir (it was genuinely malicious)"
  echo "3: Go back"
  read -p ">" x

  case "$x" in
    1)
      mv "$fullselectedfilepath" "$dir/"
      echo "Restored $selectedfilename to $dir."
      echo "$selectedfilename" >> whitelist.txt
      ;;
    2)
      rm "$fullselectedfilepath"
      echo "$selectedfilename permanently deleted."
      ;;
    3)
      continue
      ;;
    *)
      echo "Invalid choice"
      ;;
  esac

  if [ -z "$(ls -A "$malicious_dir")" ]; then
    echo "No malicious files to review."
    break
  fi
done



