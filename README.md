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
- Bonus 1: Cron Job
- Bonus 2: Whitelist
- Notes
- Author

---

## Overview

This project implements four Bash scripts that together form a simple antivirus daemon with its restore tool and a cron-based variant.

- antivirusd.sh — A long-running daemon that polls a directory every N seconds. When a change is detected, it scans the directory, flags malicious files, copies them to a quarantine directory, and deletes the originals.
- restore.sh — An interactive tool that lists quarantined files and lets the user restore a file (false positive), permanently delete it (genuine malware), or go back.
- antivirus-cron.sh — A one-shot version of the scanner designed to be scheduled by cron instead of running as a daemon.
- Makefile — Automates the pre-build step (creating the quarantine directory), running the daemon, and running the restore tool.

---

## Folder Hierarchy

9278-lab2/
├── antivirusd.sh
├── restore.sh
├── antivirus-cron.sh
├── Makefile
├── README.md
├── whitelist.txt
├── malicious_dir/
└── testdir/

---

## Prerequisites

This project targets Ubuntu Linux (or any Unix-like system with Bash).

Required packages:

- bash        -> Shell interpreter (preinstalled on Ubuntu)
- make        -> Runs the Makefile (sudo apt install make)
- cron        -> Scheduler for Bonus 1 (sudo apt install cron)
- coreutils   -> Provides ls, cp, rm, mv, basename (preinstalled)
- grep        -> Scans file contents (preinstalled)
- diffutils   -> Provides cmp (preinstalled)

All of the above come preinstalled on a standard Ubuntu installation except make and cron.

---

## Installation

Clone the repository and move into it:

git clone https://github.com/lixvin1/9278-lab2.git
cd 9278-lab2

Make the scripts executable:

chmod 755 antivirusd.sh restore.sh antivirus-cron.sh

Install make and cron if they are not already installed:

sudo apt update
sudo apt install make cron
sudo systemctl enable --now cron

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

## Bonus 1: Cron Job

Instead of running a script that loops forever with sleep, the same scan can be scheduled via cron using antivirus-cron.sh.

### How antivirus-cron.sh Differs from antivirusd.sh

- antivirusd.sh runs forever in a while true loop and uses sleep between checks.
- antivirus-cron.sh performs a single scan cycle and exits. Cron handles the repetition.
- antivirus-cron.sh does not need an interval argument, since cron controls the schedule.

### Prerequisites

- cron installed and running:

sudo apt install cron
sudo systemctl enable --now cron

- antivirus-cron.sh executable:

chmod 755 antivirus-cron.sh

- malicious_dir exists (run make setup first).

### Setup: Run Every Minute at Second 23

Open the crontab:

crontab -e

Add this line, replacing USERNAME with your actual Linux username:

* * * * * sleep 23; /home/USERNAME/9278-lab2/antivirus-cron.sh /home/USERNAME/9278-lab2/testdir /home/USERNAME/9278-lab2/malicious_dir

Save and exit.

### Every 3rd Friday at 12:31 AM

The cron expression for running at 12:31 AM on days 15 through 21 (which always contains the 3rd Friday) and on Fridays is:

31 0 15-21 * 5 /home/USERNAME/9278-lab2/antivirus-cron.sh /home/USERNAME/9278-lab2/testdir /home/USERNAME/9278-lab2/malicious_dir

Also to note that on Ubuntu, when both day-of-month (15-21) and day-of-week (5) are given, cron combines them with OR, not AND. This means the command will run on every Friday AND on every day 15 through 21, not only on the 3rd Friday.

To run strictly on the 3rd Friday only, use a day-of-week-only expression and check the date inside the script:

31 0 * * 5 /home/USERNAME/9278-lab2/antivirus-cron.sh ...

Then inside antivirus-cron.sh, add:

day=$(date +%d)
if [ "$day" -lt 15 ] || [ "$day" -gt 21 ]; then
  exit 0
fi

### Removing the Cron Job

Run crontab -e and delete the line, or crontab -r to remove all jobs.

---

## Bonus 2: Whitelist

When a file is restored through restore.sh as a false positive, it is added to whitelist.txt. On every future scan, antivirusd.sh checks whitelist.txt and skips any file whose name is listed, even if it still matches a flagged extension or keyword.

### How a File Is Added to the Whitelist

In restore.sh, after a successful restore:

echo "$selectedfilename" >> whitelist.txt

### How the Daemon Checks the Whitelist

Inside the scan_dir() function in antivirusd.sh, before classifying a file:

if [ -f whitelist.txt ] && grep -Fxq "$filename" whitelist.txt; then
  continue
fi

- grep -F treats the pattern as a fixed string (not a regex).
- grep -x matches the whole line exactly.
- grep -q runs silently.
- continue skips this file and moves to the next one.

### Persistence

whitelist.txt is a plain text file stored in the project folder. It survives restarts of the daemon, so restored files are remembered as safe across sessions.

---

## Notes

- Snapshot files (directory-info.last, directory-info.new) are stored in the project folder, not inside the monitored directory.
- The monitored directory must exist before starting the daemon.
- Files with no extension (e.g., README) are not flagged by extension.
- The whitelist.txt file persists across runs and is used to skip restored files (Bonus 2).
- antivirus-cron.sh is a one-shot script and should not be run as a long-running process.

---

## Author

Student ID: 9278
Course: Operating Systems Lab
