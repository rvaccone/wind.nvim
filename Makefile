.PHONY: test fmt fmt-check

test:
	nvim --headless -u NONE -i NONE -c "set rtp+=." -c "luafile tests/wind_spec.lua"

fmt:
	stylua .

fmt-check:
	stylua --check .
