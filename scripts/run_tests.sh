#!/usr/bin/env bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot --headless --path "$PROJECT_ROOT" -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
