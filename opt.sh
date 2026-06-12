#!/bin/sh

iwasi=./i2f32norm.wasm

wasm-opt \
	-Oz \
	-o opt.wasm \
	--enable-simd \
	--enable-relaxed-simd \
	--enable-bulk-memory \
	--enable-nontrapping-float-to-int \
	--enable-multivalue \
	--enable-tail-call \
	"${iwasi}"
