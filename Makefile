
build_parse_transform: src/*.erl src/*.hrl
	./rebar3 compile

build_transpilation_tests: build_parse_transform transpilation_tests/*.erl
	echo "Building transpilation_tests"
	ls transpilation_tests | grep "erl" | xargs -I ARG erlc -pa _build/default/lib/erlscripten/ebin transpilation_tests/ARG

transpilation_tests: build_transpilation_tests transpilation_tests/Main.purs
	cp transpilation_tests/Main.purs autogenerated_transpilation_tests/test
	cd autogenerated_transpilation_tests && spago test --purs-args "+RTS -I5 -w -A128M --"

erlscripten: build_parse_transform
	./rebar3 escriptize

compatability_benchmark: erlscripten
	ls /usr/lib/erlang/lib/stdlib-3.14/ebin | grep beam | xargs -IARG ./erlscripten -s /usr/lib/erlang/lib/stdlib-3.14/ebin/ARG -o test.purs | grep stdlib

clean:
	rm erlscripten
	rm -rf _build
	rm -rf autogenerated_transpilation_tests
	rm -f *beam
	rm .psc-ide-port
	rm test.purs
