do_compile:prepend:kv260-vision() {
    sed -i 's/rootwait rw"/rootwait rw cma=256M"/' ${WORKDIR}/boot.cmd
}
