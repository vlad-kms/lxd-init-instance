#!/bin/sh

before_init_container() {
  debug "DISPATH HOOK: before_init_container"
}

after_init_container() {
  debug "DISPATH HOOK: after_init_container"
}

before_start() {
  debug "DISPATH HOOK: hook_beforestartr"
}

after_start() {
  debug "DISPATH HOOK: hook_afterstart"
}

before_export() {
  debug "DISPATH HOOK: before_export"
}

after_export() {
  debug "DISPATH HOOK: after_export"
}
