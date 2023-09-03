#!/bin/sh

before_init_container() {
  echo "DISPATH HOOK: before_init_container"
}

after_init_container() {
  echo "DISPATH HOOK: after_init_container"
}

before_start() {
  echo "DISPATH HOOK: hook_beforestartr"
}

after_start() {
  echo "DISPATH HOOK: hook_afterstart"
}

before_export() {
  echo "DISPATH HOOK: before_export"
}

after_export() {
  echo "DISPATH HOOK: after_export"
}
