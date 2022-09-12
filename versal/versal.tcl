connect
after 1000
target 1
rst
targets -set -nocase -filter {name =~ "*Versal*"}
device program "./BOOT.BIN"
