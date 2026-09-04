APP     = $(HOME)/Applications/MouseMap.app
AGENT   = $(HOME)/Library/LaunchAgents/ai.mpiv.mousemap.plist
CONFIG  = $(HOME)/.config/mousemap.json
BUNDLE  = ai.mpiv.mousemap

build: mousemap.swift
	swiftc -O -o mousemap mousemap.swift -framework Cocoa -framework IOKit

install: build
	-launchctl bootout gui/$$(id -u)/$(BUNDLE) 2>/dev/null
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(HOME)/.config" "$(HOME)/Library/LaunchAgents"
	cp mousemap "$(APP)/Contents/MacOS/mousemap"
	cp Info.plist "$(APP)/Contents/Info.plist"
	codesign -s - -f -i $(BUNDLE) "$(APP)"
	[ -f "$(CONFIG)" ] || cp mousemap.example.json "$(CONFIG)"
	sed "s#__HOME__#$(HOME)#g" ai.mpiv.mousemap.plist > "$(AGENT)"
	# ad-hoc signing changes the code hash on every build, so old grants stop matching
	-tccutil reset Accessibility $(BUNDLE)
	-tccutil reset ListenEvent $(BUNDLE)
	launchctl bootstrap gui/$$(id -u) "$(AGENT)"
	@echo "Allow the Accessibility and Input Monitoring prompts, then: tail -f ~/Library/Logs/mousemap.log"

learn: build
	./mousemap --learn

reload:
	pkill -HUP mousemap

uninstall:
	-launchctl bootout gui/$$(id -u)/$(BUNDLE) 2>/dev/null
	rm -rf "$(APP)" "$(AGENT)"
	-tccutil reset Accessibility $(BUNDLE)
	-tccutil reset ListenEvent $(BUNDLE)

clean:
	rm -f mousemap

.PHONY: build install learn reload uninstall clean
