#!/bin/bash
ps aux | grep -E "(bash|python|make)" | tr -s ' ' | cut -d ' ' -f 2 | xargs kill -9
