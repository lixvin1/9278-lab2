# Lab 2: Simple Antivirus Daemon

A simplified antivirus system built in Bash. It monitors a directory for changes, flags files based on extensions or content, quarantines them, and lets you review quarantined files through an interactive restore tool.

---

## Table of Contents

- Overview
- Folder Hierarchy
- Prerequisites
- Installation
- Usage
- Malicious File Rules
- Where the Lists Are Defined
- How It Works
- Notes
- Author

---

## Overview

This project implements three Bash scripts that together form a simple antivirus daemon with its restore tool.

- antivirusd.sh — A long-running daemon that polls a directory every N seconds. When a change is detected, it scans the directory, flags malicious files, copies them to a quarantine directory, and deletes the originals.
- restore.sh — An interactive tool that lists quarantined files and lets the user restore a file (false positive), permanently delete it (genuine malware), or go back.
- Makefile — Automates the pre-build step (creating the quarantine directory), running the daemon, and running the restore tool.

---

## Folder Hierarchy

9278-lab2/
├── antivirusd.sh
├── restore.sh
├── Makefile
├── README.md
├── malicious_dir/
└── testdir/

---

## Prerequisites

This project targets Ubuntu Linux (or any Unix-like system with Bash).

Required packages:

- bash        -> Shell interpreter (preinstalled on Ubuntu)
- make        -> Runs the Makefile (sudo apt install make)
- coreutils   -> Provides ls, cp, rm, mv, basename (preinstalled)
- grep        -> Scans file contents (preinstalled)
- diffutils   -> Provides cmp (preinstalled)

All of the above come preinstalled on a standard Ubuntu installation except make.

---

## Installation

Clone the repository and move into it:

git clone https://github.com/lixvin1/9278-lab2.git
cd 9278-lab2

Make the scripts executable:

chmod 755 antivirusd.sh restore.sh

Install make if it is not already installed:

sudo apt update
sudo apt install make

---

## Usage

### 1. Setup

Create the quarantine directory:

make setup

### 2. Run the Antivirus Daemon

make run

This runs:

./antivirusd.sh testdir malicious_dir 5

The daemon will:

1. Scan testdir immediately on the first run.
2. Take a snapshot of the directory listing.
3. Every 5 seconds, compare the current listing to the snapshot.
4. If a change is detected, scan the directory again, quarantine any malicious files, and regenerate the snapshot.

To use custom arguments:

make run DIR=mydir MALICIOUS_DIR=quarantine INTERVAL=3

Press Ctrl+C to stop the daemon.

### 3. Run the Restore Tool

make restore

This runs:

./restore.sh testdir malicious_dir

You will see a numbered list of quarantined files. Pick one by number, then choose:

1: Restore this file back into dir (it was a false positive)
2: Permanently delete this file from malicious_dir (it was genuinely malicious)
3: Go back

Restored files are added to whitelist.txt so they are skipped by future scans.

---

## Malicious File Rules

A file is treated as malicious if it matches at least one of the following rules:

1. Flagged extension — the file's final extension is one of:
   .exe, .bat, .vbs, .scr, .ps1

2. Flagged content — the file's contents contain any of these keywords (case-insensitive, matches anywhere including inside longer words):
   virus, trojan, malware, worm, ransomware

When a file is flagged, the daemon:

1. Prints: <file> is malicious and it is DELETED
2. Copies the file into malicious_dir/ (keeping its original filename)
3. Deletes the original file from the monitored directory

---

## Where the Lists Are Defined

Both lists are hardcoded inside the scan_dir() function in antivirusd.sh:

- Flagged extensions are defined in the case "$filename" in block:

case "$filename" in
  *.exe|*.bat|*.vbs|*.scr|*.ps1)
    malicious=1
    ;;
esac

- Flagged keywords are defined in the grep -qiE pattern:

if grep -qiE 'virus|trojan|malware|worm|ransomware' "$file"; then
  malicious=1
fi

To change or extend the rules, edit these two locations.

---

## How It Works

### Change Detection

The daemon uses ls -l to snapshot the directory:

ls -l "$dir" > directory-info.last
ls -l "$dir" > directory-info.new

It compares the two snapshots with cmp -s:

- If identical: no change, sleep.
- If different: change detected, scan and regenerate directory-info.last.

### Scan and Quarantine

For every regular file in the directory, the daemon:

1. Extracts the filename with basename.
2. Checks the extension against the flagged list.
3. Searches the content for flagged keywords.
4. If either check passes, the file is quarantined.

### Restore Workflow

The restore tool lists all files in malicious_dir, lets the user pick one, and offers three actions: restore, delete, or go back. On restore, the filename is appended to whitelist.txt.

---

## Notes

- Snapshot files (directory-info.last, directory-info.new) are stored in the project folder, not inside the monitored directory.
- The monitored directory must exist before starting the daemon.
- Files with no extension (e.g., README) are not flagged by extension.
- The whitelist.txt file persists across runs and is used to skip restored files (Bonus 2).

---

## Author

Student ID: 9278
Course: Operating Systems Lab
