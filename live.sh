#!/bin/bash
ffplay -probesize 5M -analyzeduration 5M -headers "referer: https://www.weekseries.info/\r\norigin: https://www.weekseries.info\r\nuser-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36" -sync video -framedrop -autoexit "https://cdn001.sytrano.cfd/C/chefe-de-guerra-2025/01-temporada/01/stream.m3u8"
