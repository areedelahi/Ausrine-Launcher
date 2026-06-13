#!/bin/bash
osascript -e 'tell application "System Events" to set frontmost of every process whose name is "java" to true'
