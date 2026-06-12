#!/bin/sh

wsm=./i2f32norm.wasm
wsm=./opt.wasm

aot=./i2f32norm.aot

input0() {
	printf ''
}

input1() {
	printf 'ffff ffff' | xxd -r -ps
}

input2() {
	(
		printf 'ffff ffff'
		printf '0000 0000'
	) |
		xxd -r -ps
}

input3() {
	(
		printf 'ffff ffff'
		printf 'ffff ff7f'
		printf '0000 0000'
	) |
		xxd -r -ps
}

input4() {
	(
		printf 'ffff ffff'
		printf 'ffff ff7f'
		printf 'ffff ff3f'
		printf '0000 0000'
	) |
		xxd -r -ps
}

input5() {
	(
		printf 'ffff ffff'
		printf 'ffff ff7f'
		printf 'ffff ff3f'
		printf 'ffff ff1f'
		printf '0000 0000'
	) |
		xxd -r -ps
}

input6() {
	(
		printf 'ffff ffff'
		printf 'ffff ff7f'
		printf 'ffff ff3f'
		printf 'ffff ff1f'
		printf 'ffff ff0f'
		printf '0000 0000'
	) |
		xxd -r -ps
}

input7() {
	(
		printf 'ffff ffff'
		printf 'ffff ff7f'
		printf 'ffff ff3f'
		printf 'ffff ff1f'
		printf 'ffff ff0f'
		printf 'ffff ff07'
		printf '0000 0000'
	) |
		xxd -r -ps
}

f4human() {
	impf='import functools;'
	imps='import sys; import struct;'
	impo='import operator;'

	imports="${impf} ${imps} ${impo}"

	cat /dev/stdin |
    python3 -c "${imports}"' s=struct.Struct("<f"); functools.reduce(
      lambda state, f: f(state),
      [
        functools.partial(map, s.unpack),
        functools.partial(map, operator.itemgetter(0)),
        functools.partial(map, print),
        lambda prints: sum(1 for _ in prints),
      ],
      iter(
        functools.partial(sys.stdin.buffer.read, 4),
        b""
      ),
    )'
}

input1GiB(){
  dd \
    if=/dev/zero \
    bs=1048576 \
    count=1024 \
    status=none
}

stat(){
  dd \
    of=/dev/null \
    bs=1048576 \
    status=progress
}

conv_wazero(){
  wazero run "${wsm}"
}

conv_iwasm(){
  iwasm "${wsm}"
}

input7 |
  conv_wazero |
  f4human
