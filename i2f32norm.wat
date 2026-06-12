(module

  (import "wasi_snapshot_preview1" "proc_exit" (func $proc_exit (param i32)))

  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))

  (import "wasi_snapshot_preview1" "fd_read"
    (func $fd_read (param i32 i32 i32 i32) (result i32)))

  (global $STDIN i32 (i32.const 0))
  (global $STDOUT i32 (i32.const 1))
  (global $STDERR i32 (i32.const 2))

  (global $READ_BUF_SIZE i32 (i32.const 32768))

  (global $FD_READ_IOVEC_PTR i32 (i32.const 0x0001_0000))
  (global $FD_READ_IOBUF_PTR i32 (i32.const 0x0002_0000))
  (global $FD_READ_BREAD_PTR i32 (i32.const 0x0003_0000))

  (global $FD_WRIT_IOVEC_PTR i32 (i32.const 0x0004_0000))
  (global $FD_WRIT_IOBUF_PTR i32 (i32.const 0x0005_0000))
  (global $FD_WRIT_BWRIT_PTR i32 (i32.const 0x0006_0000))

  (memory (export "memory") 7)

  (func $fd2buf
    (param $fd i32)
    (param $iovec_ptr i32)
    (param $iobuf_ptr i32)
    (param $bread_ptr i32)

    (param $len i32)

    (result i32)

    ;; result:
    ;;   - 0 on EOF
    ;;   - <0 on error
    ;;   - >0 when some data read

    ;; setup the iovec
    local.get $iovec_ptr
    local.get $iobuf_ptr
    i32.store
    local.get $iovec_ptr
    local.get $len
    i32.store offset=4

    local.get $fd
    local.get $iovec_ptr
    i32.const 1 ;; single buffer
    local.get $bread_ptr
    call $fd_read
    i32.const 0
    i32.ne
    if
      i32.const 1
      call $proc_exit
      i32.const -1
      return
    end

    local.get $bread_ptr
    i32.load
  )

  (func $fd2buf_read_full_or_eof
    (param $fd i32)
    (param $iovec_ptr i32)
    (param $iobuf_ptr i32)
    (param $bread_ptr i32)

    (param $len i32)

    (result i32)

    (local $bytes_read_cur i32)
    (local $bytes_read_tot i32)

    (local $bytes2read i32)

    (local $ptr2 i32)

    i32.const 0
    local.tee $bytes_read_cur
    local.set $bytes_read_tot

    loop
      ;; compute the bytes to read
      local.get $len
      local.get $bytes_read_tot
      i32.sub
      local.tee $bytes2read
      i32.const 0
      i32.eq
      ;; fully read -> return len
      if
        local.get $len
        return
      end

      ;; compute the ptr
      local.get $iobuf_ptr
      local.get $bytes_read_tot
      i32.add
      local.set $ptr2

      ;; read
      local.get $fd
      local.get $iovec_ptr
      local.get $ptr2
      local.get $bread_ptr
      local.get $bytes2read
      call $fd2buf
      local.tee $bytes_read_cur
      i32.const 0
      i32.eq
      ;; return on EOF
      if
        local.get $bytes_read_tot
        return
      end

      ;; update the tot
      local.get $bytes_read_tot
      local.get $bytes_read_cur
      i32.add
      local.set $bytes_read_tot

      br 0
    end

    unreachable
  )

  (func $stdin2buf (result i32)
    ;; result:
    ;;   - 0: on no data
    ;;   - >0: number of i64
    ;;   - <0: error

    (local $ret i32)

    global.get $STDIN
    global.get $FD_READ_IOVEC_PTR
    global.get $FD_READ_IOBUF_PTR
    global.get $FD_READ_BREAD_PTR
    global.get $READ_BUF_SIZE
    call $fd2buf_read_full_or_eof
    local.tee $ret
    i32.const 0
    i32.eq
    if
      i32.const 0
      return
    end

    local.get $ret
    i32.const 0
    i32.lt_s
    if
      i32.const -1
      return
    end

    local.get $ret
    i32.const 2
    i32.shr_u
  )

  (func $rdr2wtr_copy (param $cnt i32) (result i32)
    global.get $FD_WRIT_IOBUF_PTR
    global.get $FD_READ_IOBUF_PTR
    local.get $cnt
    i32.const 2
    i32.shl
    memory.copy
    local.get $cnt
  )

  (func $int2float32norm64f (param $cnt i32) (result i32)
    (local $eptr i32)
    (local $ptr i32)

    (local $optr i32)

    (local $tmp f32)

    ;; compute the end pointer
    global.get $FD_READ_IOBUF_PTR
    local.get $cnt
    i32.const 2
    i32.shl
    i32.add
    local.set $eptr

    global.get $FD_READ_IOBUF_PTR
    local.set $ptr

    global.get $FD_WRIT_IOBUF_PTR
    local.set $optr

    loop
      local.get $eptr
      local.get $ptr
      i32.le_u
      if
        local.get $cnt
        return
      end

      ;; convert
      ;;;; get the integer
      local.get $ptr
      i32.load
      f64.convert_i32_u
      ;;;; normalize
      f64.const 4294967295.0
      f64.div
      f32.demote_f64
      local.set $tmp

      ;; save
      local.get $optr
      local.get $tmp
      f32.store

      ;; advance the ptr
      local.get $ptr
      i32.const 4
      i32.add
      local.set $ptr

      local.get $optr
      i32.const 4
      i32.add
      local.set $optr

      br 0
    end

    unreachable
  )

  (func $int2float32norm (param $cnt i32) (result i32)
    (local $eptr i32)
    (local $ptr i32)

    (local $optr i32)

    (local $tmp f32)

    ;; compute the end pointer
    global.get $FD_READ_IOBUF_PTR
    local.get $cnt
    i32.const 2
    i32.shl
    i32.add
    local.set $eptr

    global.get $FD_READ_IOBUF_PTR
    local.set $ptr

    global.get $FD_WRIT_IOBUF_PTR
    local.set $optr

    loop
      local.get $eptr
      local.get $ptr
      i32.le_u
      if
        local.get $cnt
        return
      end

      ;; convert
      ;;;; get the integer
      local.get $ptr
      i32.load
      f32.convert_i32_u
      ;;;; normalize
      f32.const 4294967295.0
      f32.div
      local.set $tmp

      ;; save
      local.get $optr
      local.get $tmp
      f32.store

      ;; advance the ptr
      local.get $ptr
      i32.const 4
      i32.add
      local.set $ptr

      local.get $optr
      i32.const 4
      i32.add
      local.set $optr

      br 0
    end

    unreachable
  )

  (func $buf2stdout (param $cnt i32) (result i32)
    (local $bcnt i32)

    ;; compute the byte count
    local.get $cnt
    i32.const 2
    i32.shl
    local.set $bcnt

    ;; setup the iovec
    global.get $FD_WRIT_IOVEC_PTR
    global.get $FD_WRIT_IOBUF_PTR
    i32.store
    global.get $FD_WRIT_IOVEC_PTR
    local.get $bcnt
    i32.store offset=4

    global.get $STDOUT
    global.get $FD_WRIT_IOVEC_PTR
    i32.const 1 ;; single buffer
    global.get $FD_WRIT_BWRIT_PTR
    call $fd_write
    i32.const 0
    i32.ne
    if
      i32.const 1
      call $proc_exit
      i32.const 0
      return
    end

    global.get $FD_WRIT_BWRIT_PTR
    i32.load
    local.get $bcnt
    i32.ne
    if
      i32.const 1
      call $proc_exit
      i32.const 0
      return
    end

    local.get $cnt
  )

  (func $main (export "_start")
    (local $ret i32)

    loop

      call $stdin2buf
      ;;call $rdr2wtr_copy
      call $int2float32norm
      call $buf2stdout
      local.tee $ret
      i32.const 0
      i32.lt_s
      if
        i32.const 1
        call $proc_exit
        return
      end

      local.get $ret
      i32.const 0
      i32.eq
      if
        i32.const 0
        call $proc_exit
        return
      end

      br 0

    end
  )

)
